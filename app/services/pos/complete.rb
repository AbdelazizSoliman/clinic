module Pos
  class Complete
    include Support

    def initialize(sale:, actor:, idempotency_key:, payments:, loyalty_points: 0)
      @sale, @actor, @key, @payment_specs = sale, actor, idempotency_key.to_s.strip, Array(payments)
      @loyalty_points = loyalty_points.to_i
    end

    def call
      return failure(@sale, "تعارض مؤسسة عملية نقطة البيع") unless Operations::TenantGuard.same_organization?(
        @sale, @sale.branch, @sale.cashier_session, @sale.cashier, @sale.customer)
      existing = PosSale.completed.find_by(completion_idempotency_key: @key) if @key.present?
      return success(existing) if existing
      return failure(@sale, "مفتاح إتمام العملية مطلوب") if @key.blank?
      return failure(@sale, "غير مصرح بتشغيل نقطة البيع") unless authorized?

      errors = []
      PosSale.transaction do
        @sale.cashier_session.lock!
        @sale.lock!
        if @sale.completed?
          errors << "عملية البيع مكتملة بالفعل"
          raise ActiveRecord::Rollback
        end
        unless @sale.draft? && @sale.cashier_session.open?
          errors << "عملية البيع أو جلسة الصندوق غير متاحة"
          raise ActiveRecord::Rollback
        end
        Recalculate.call(@sale)
        apply_loyalty_redemption!(errors)
        items = @sale.items.includes(:product, prescription_review_item: :dispensed_product).order(:product_id).to_a
        product_ids = items.filter_map { |item| effective_product(item)&.id }
        products = Product.where(id: product_ids).order(:id).lock.index_by(&:id)
        errors.concat(validate_items(items, products))
        errors.concat(safety_errors)
        payment_attributes = normalize_payments(@sale.total_cents, errors)
        raise ActiveRecord::Rollback if errors.any?

        consume_batches!(items, products, errors)
        raise ActiveRecord::Rollback if errors.any?
        apply_wallet_payments!(payment_attributes, errors)
        raise ActiveRecord::Rollback if errors.any?
        payment_attributes.each { |attributes| @sale.payments.create!(attributes) }
        audit(@actor, @sale, "pos_payment_recorded",
          methods: payment_attributes.map { |attributes| attributes[:payment_method] },
          amount_cents: payment_attributes.sum { |attributes| attributes[:amount_cents] })
        @sale.update!(status: :completed, completed_at: Time.current, completion_idempotency_key: @key)
        Loyalty::Earn.new(source: @sale, customer: @sale.customer, actor: @actor,
          idempotency_key: "pos-loyalty-earn:#{@sale.id}").call if @sale.customer
        audit(@actor, @sale, "pos_sale_completed",
          number: @sale.number, total_cents: @sale.total_cents, session: @sale.cashier_session.identifier)
      end
      return failure(@sale, errors) if errors.any?
      success(@sale)
    rescue ActiveRecord::RecordNotUnique
      existing = PosSale.completed.find_by(completion_idempotency_key: @key)
      existing ? success(existing) : failure(@sale, "تعذر إتمام البيع؛ حاول مرة أخرى")
    rescue ActiveRecord::RecordInvalid => error
      failure(@sale, error.record.errors.full_messages)
    end

    private

    def apply_loyalty_redemption!(errors)
      return if @loyalty_points.zero?
      unless @sale.customer&.customer?
        errors << "يلزم ربط عميل لاستبدال النقاط"
        return
      end
      redemption = Loyalty::Redeem.new(customer: @sale.customer, source: @sale,
        requested_points: @loyalty_points, maximum_value_cents: @sale.total_cents,
        actor: @actor, idempotency_key: "pos-loyalty-redeem:#{@sale.id}").call
      unless redemption.success?
        errors.concat(redemption.errors)
        return
      end
      @sale.update!(loyalty_points_redeemed: redemption.points, loyalty_discount_cents: redemption.value_cents,
        total_cents: @sale.total_cents - redemption.value_cents)
    end

    def apply_wallet_payments!(attributes, errors)
      wallet_amount = attributes.select { |entry| entry[:payment_method] == "wallet" }.sum { |entry| entry[:amount_cents] }
      return if wallet_amount.zero?
      unless @sale.customer&.customer?
        errors << "يلزم ربط عميل لاستخدام المحفظة"
        return
      end
      debit = Wallet::Debit.new(customer: @sale.customer, amount_cents: wallet_amount, source: @sale,
        actor: @actor, reason: "دفع محفظة لنقطة البيع #{@sale.number}",
        idempotency_key: "pos-wallet-payment:#{@sale.id}").call
      if debit.success?
        @sale.update!(wallet_paid_cents: wallet_amount)
      else
        errors.concat(debit.errors)
      end
    end

    def authorized?
      @actor&.can_operate_pos? && (@sale.cashier_id == @actor.id || @actor.admin?)
    end

    def validate_items(items, products)
      return [ "سلة نقطة البيع فارغة" ] if items.empty?
      items.filter_map do |item|
        review_item = item.prescription_review_item
        next if review_item&.rejected?
        product = effective_product(item)
        if !product&.active?
          "#{item.product_name} غير نشط"
        elsif item.requires_prescription? && !review_item&.dispensable?
          "#{item.product_name} يحتاج قرارًا سريريًا نهائيًا"
        elsif item.quantity > product.available_to_sell_quantity(@sale.branch)
          "الكمية المتاحة من #{item.product_name} غير كافية"
        end
      end
    end

    # Unresolved blocking findings stop the sale. Only a pharmacist can clear them, and never
    # from the completion path itself.
    def safety_errors
      review = @sale.prescription_review
      return [] unless review
      blocking = DrugSafety::Gate.blocking_findings(review.reload)
      blocking.any? ? [ DrugSafety::Gate.blocked_message(blocking) ] : []
    end

    def normalize_payments(total, errors)
      return [] if total.zero? && @payment_specs.all? { |spec| spec[:amount_cents].to_i.zero? }
      attributes = @payment_specs.filter_map do |spec|
        method = spec[:payment_method].to_s
        amount = spec[:amount_cents].to_i
        unless PosPayment.payment_methods.key?(method) && amount.positive?
          errors << "بيانات الدفع غير صحيحة"
          next
        end
        if method == "cash"
          tendered = spec[:tendered_cents].to_i
          if tendered < amount
            errors << "المبلغ النقدي المستلم غير كافٍ"
            next
          end
          { payment_method: method, amount_cents: amount, tendered_cents: tendered,
            change_cents: tendered - amount }
        elsif method == "external_card"
          { payment_method: method, amount_cents: amount, change_cents: 0,
            external_reference: spec[:external_reference].to_s.squish.presence }
        else
          { payment_method: method, amount_cents: amount, change_cents: 0 }
        end
      end
      errors << "إجمالي المدفوعات يجب أن يساوي إجمالي البيع" unless attributes.sum { |entry| entry[:amount_cents] } == total
      attributes
    end

    def consume_batches!(items, products, errors)
      items.each do |item|
        next if item.prescription_review_item&.rejected?
        remaining = item.quantity
        product = effective_product(item)
        batches = InventoryBatch.where(branch: @sale.branch, product_id: product.id).allocatable.fefo.lock.to_a
        batches.each do |batch|
          quantity = [ remaining, batch.available_quantity ].min
          next unless quantity.positive?
          product = products.fetch(product.id)
          product_before = product.stock_quantity
          batch_before = batch.on_hand_quantity
          batch.update!(on_hand_quantity: batch_before - quantity)
          Inventory::BatchAggregate.sync_product!(product)
          movement = product.inventory_movements.create!(actor: @actor, inventory_batch: batch,
            reference: item, movement_type: :pos_sale, quantity_delta: -quantity,
            quantity_before: product_before, quantity_after: product.stock_quantity,
            batch_quantity_before: batch_before, batch_quantity_after: batch.on_hand_quantity,
            reason: "بيع نقطة البيع #{@sale.number}",
            idempotency_key: "pos-sale:#{@sale.id}:item:#{item.id}:batch:#{batch.id}")
          item.batch_allocations.create!(inventory_batch: batch, inventory_movement: movement,
            quantity:, unit_cost_cents: batch.unit_cost_cents)
          remaining -= quantity
          break if remaining.zero?
        end
        errors << "الكمية المتاحة من #{item.product_name} غير كافية" if remaining.positive?
        break if errors.any?
      end
    end

    def effective_product(item)
      review_item = item.prescription_review_item
      review_item&.dispensable? ? review_item.effective_product : item.product
    end
  end
end
