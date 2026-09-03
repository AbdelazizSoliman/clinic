module Purchasing
  class Receive
    include Support
    Result = Data.define(:success?, :purchase_order, :receipt, :errors)

    def initialize(purchase_order:, actor:, quantities:, idempotency_key:, batches: {},
      supplier_document_number: nil, notes: nil, received_at: Time.current, lock_version: nil)
      @purchase_order, @actor, @idempotency_key = purchase_order, actor, idempotency_key.to_s
      @quantities, @supplier_document_number, @notes = quantities.to_h, supplier_document_number, notes
      @batches = batches.to_h
      @received_at, @lock_version = received_at, lock_version
    end

    def call
      return failure(nil, "غير مصرح باستلام المشتريات") unless @actor&.can_receive_purchasing?
      return failure(nil, "تعارض مؤسسة أمر الشراء") unless Operations::TenantGuard.same_organization?(
        @purchase_order, @purchase_order.branch, @purchase_order.supplier, @actor)
      return failure(nil, "معرف عملية الاستلام مطلوب") if @idempotency_key.blank?
      existing = PurchaseReceipt.find_by(idempotency_key: @idempotency_key)
      return success(existing) if existing&.purchase_order_id == @purchase_order.id
      return failure(nil, "معرف عملية الاستلام مستخدم لأمر آخر") if existing

      receipt = nil
      PurchaseOrder.transaction do
        @purchase_order.lock!
        stale!
        return failure(nil, "لا يمكن الاستلام في حالة أمر الشراء الحالية") unless @purchase_order.receivable?

        lines = @purchase_order.items.order(:id).lock.index_by { |item| item.id.to_s }
        requested = @quantities.filter_map do |id, raw|
          quantity = Integer(raw, exception: false)
          next if quantity.nil? || quantity.zero?
          return failure(nil, "كمية الاستلام يجب أن تكون موجبة") if quantity.negative?
          item = lines[id.to_s]
          return failure(nil, "بند الاستلام غير صالح") unless item
          return failure(nil, "كمية الاستلام تتجاوز المتبقي للمنتج #{item.product_name_snapshot}") if quantity > item.outstanding_quantity
          specs = batch_specs_for(item, quantity)
          return failure(nil, "بيانات التشغيلات أو تواريخ صلاحيتها غير مكتملة") if specs.any? { |spec| spec[:batch_number].blank? || spec[:expiry_date].blank? || !spec[:quantity].positive? }
          return failure(nil, "يجب أن يساوي مجموع كميات التشغيلات كمية الاستلام") unless specs.sum { |spec| spec[:quantity] } == quantity
          [ item, quantity, specs ]
        end
        return failure(nil, "أدخل كمية مستلمة واحدة على الأقل") if requested.empty?

        Product.where(id: requested.map { |item, _, _| item.product_id }.sort).order(:id).lock.load
        reference = "PR-#{@purchase_order.id}-#{Digest::SHA256.hexdigest(@idempotency_key).first(10).upcase}"
        receipt = @purchase_order.receipts.create!(branch: @purchase_order.branch, reference:, received_by: @actor, received_at: @received_at,
          supplier_document_number: @supplier_document_number.to_s.squish.presence, notes: @notes.to_s.squish.presence,
          idempotency_key: @idempotency_key)

        requested.each do |item, quantity, specs|
          product = item.product.reload
          receipt_item = receipt.items.create!(purchase_order_item: item, quantity:,
            unit_cost_cents: item.unit_cost_cents, inventory_movement: nil)
          specs.each_with_index do |spec, index|
            product_before = product.stock_quantity
            batch = InventoryBatch.create!(branch: @purchase_order.branch, product:, supplier: @purchase_order.supplier, purchase_receipt: receipt,
              purchase_receipt_item: receipt_item, batch_number: spec[:batch_number],
              lot_number: spec[:lot_number], manufacture_date: spec[:manufacture_date],
              expiry_date: spec[:expiry_date], received_at: @received_at,
              original_quantity: spec[:quantity], on_hand_quantity: spec[:quantity], reserved_quantity: 0,
              unit_cost_cents: item.unit_cost_cents, notes: spec[:notes])
            Inventory::BatchAggregate.sync_product!(product)
            product.inventory_movements.create!(actor: @actor, reference: receipt, inventory_batch: batch,
              movement_type: :purchase_received, quantity_delta: spec[:quantity],
              quantity_before: product_before, quantity_after: product.stock_quantity,
              batch_quantity_before: 0, batch_quantity_after: spec[:quantity],
              reason: "استلام التشغيلة #{batch.batch_number} عبر #{receipt.reference}",
              idempotency_key: "purchase-receipt:#{receipt.id}:line:#{item.id}:batch:#{index}")
          end
          item.update!(received_quantity: item.received_quantity + quantity)
        end

        from = @purchase_order.status
        complete = @purchase_order.items.reload.all? { |item| item.outstanding_quantity.zero? }
        @purchase_order.update!(status: complete ? :received : :partially_received,
          received_at: complete ? @received_at : nil)
        event(@purchase_order, "receipt_posted", from:, to: @purchase_order.status,
          metadata: { receipt_reference: receipt.reference, quantity: requested.sum { |_, quantity, _| quantity } })
        event(@purchase_order, complete ? "fully_received" : "partially_received", from:, to: @purchase_order.status)
        audit(@purchase_order, "purchase_receipt_posted", receipt_reference: receipt.reference,
          quantity: requested.sum { |_, quantity, _| quantity })
        audit(@purchase_order, complete ? "purchase_order_fully_received" : "purchase_order_partially_received",
          number: @purchase_order.number, receipt_reference: receipt.reference)
        notify(User.where(active: true, role: :admin), @purchase_order, "purchase_receipt_posted",
          complete ? "اكتمل استلام أمر شراء" : "تم استلام جزء من أمر شراء", "purchase-receipt-posted:#{receipt.id}")
      end
      success(receipt)
    rescue ActiveRecord::RecordNotUnique
      existing = PurchaseReceipt.find_by(idempotency_key: @idempotency_key)
      existing&.purchase_order_id == @purchase_order.id ? success(existing) : failure(nil, "معرف عملية الاستلام مستخدم لأمر آخر")
    rescue ActiveRecord::StaleObjectError
      failure(receipt, "تم تحديث أمر الشراء بواسطة مستخدم آخر؛ أعد تحميل الصفحة")
    rescue ActiveRecord::RecordInvalid => error
      failure(receipt, error.record.errors.full_messages.join("، "))
    end

    private

    def batch_specs_for(item, quantity)
      raw_specs = normalize_batch_specs(@batches[item.id.to_s] || @batches[item.id])
      raw_specs = [ {
        batch_number: "B-#{Digest::SHA256.hexdigest("#{@idempotency_key}:#{item.id}").first(16).upcase}",
        expiry_date: Date.current + 2.years,
        quantity:
      } ] if raw_specs.empty?
      raw_specs.map.with_index do |raw, index|
        values = raw.to_h.symbolize_keys
        {
          batch_number: values[:batch_number].to_s.squish.upcase,
          lot_number: values[:lot_number].to_s.squish.upcase.presence,
          manufacture_date: values[:manufacture_date].presence,
          expiry_date: values[:expiry_date].presence,
          quantity: Integer(values[:quantity], exception: false) || (raw_specs.one? && index.zero? ? quantity : 0),
          notes: values[:notes].to_s.squish.presence
        }
      end
    end

    def normalize_batch_specs(raw_specs)
      return [] if raw_specs.blank?
      return raw_specs if raw_specs.is_a?(Array)
      return Array(raw_specs) unless raw_specs.is_a?(Hash)

      specs = raw_specs
      spec_keys = specs.keys.map(&:to_s)
      spec_keys.intersect?(%w[batch_number lot_number manufacture_date expiry_date quantity notes]) ? [ specs ] : specs.values
    end

    def stale!
      raise ActiveRecord::StaleObjectError.new(@purchase_order, "receive") if @lock_version && @purchase_order.lock_version != @lock_version.to_i
    end
    def success(receipt) = Result.new(success?: true, purchase_order: @purchase_order, receipt:, errors: [])
    def failure(receipt, message) = Result.new(success?: false, purchase_order: @purchase_order, receipt:, errors: [ message ])
  end
end
