module Pos
  class Complete
    include Support

    def initialize(sale:, actor:, idempotency_key:, payments:)
      @sale, @actor, @key, @payment_specs = sale, actor, idempotency_key.to_s.strip, Array(payments)
    end

    def call
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
        items = @sale.items.includes(:product).order(:product_id).to_a
        products = Product.where(id: items.map(&:product_id)).order(:id).lock.index_by(&:id)
        errors.concat(validate_items(items, products))
        payment_attributes = normalize_payments(@sale.total_cents, errors)
        raise ActiveRecord::Rollback if errors.any?

        consume_batches!(items, products, errors)
        raise ActiveRecord::Rollback if errors.any?
        payment_attributes.each { |attributes| @sale.payments.create!(attributes) }
        audit(@actor, @sale, "pos_payment_recorded",
          methods: payment_attributes.map { |attributes| attributes[:payment_method] },
          amount_cents: payment_attributes.sum { |attributes| attributes[:amount_cents] })
        @sale.update!(status: :completed, completed_at: Time.current, completion_idempotency_key: @key)
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

    def authorized?
      @actor&.can_operate_pos? && (@sale.cashier_id == @actor.id || @actor.admin?)
    end

    def validate_items(items, products)
      return [ "سلة نقطة البيع فارغة" ] if items.empty?
      items.filter_map do |item|
        product = products[item.product_id]
        if !product&.active?
          "#{item.product_name} غير نشط"
        elsif item.requires_prescription? && !item.prescription_approved?
          "#{item.product_name} يحتاج اعتماد صيدلي"
        elsif item.quantity > product.available_to_sell_quantity
          "الكمية المتاحة من #{item.product_name} غير كافية"
        end
      end
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
        else
          { payment_method: method, amount_cents: amount, change_cents: 0,
            external_reference: spec[:external_reference].to_s.squish.presence }
        end
      end
      errors << "إجمالي المدفوعات يجب أن يساوي إجمالي البيع" unless attributes.sum { |entry| entry[:amount_cents] } == total
      attributes
    end

    def consume_batches!(items, products, errors)
      items.each do |item|
        remaining = item.quantity
        batches = InventoryBatch.where(product_id: item.product_id).allocatable.fefo.lock.to_a
        batches.each do |batch|
          quantity = [ remaining, batch.available_quantity ].min
          next unless quantity.positive?
          product = products.fetch(item.product_id)
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
  end
end
