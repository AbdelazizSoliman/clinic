module Purchasing
  class Receive
    include Support
    Result = Data.define(:success?, :purchase_order, :receipt, :errors)

    def initialize(purchase_order:, actor:, quantities:, idempotency_key:, supplier_document_number: nil,
      notes: nil, received_at: Time.current, lock_version: nil)
      @purchase_order, @actor, @idempotency_key = purchase_order, actor, idempotency_key.to_s
      @quantities, @supplier_document_number, @notes = quantities.to_h, supplier_document_number, notes
      @received_at, @lock_version = received_at, lock_version
    end

    def call
      return failure(nil, "غير مصرح باستلام المشتريات") unless @actor&.can_receive_purchasing?
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
          [ item, quantity ]
        end
        return failure(nil, "أدخل كمية مستلمة واحدة على الأقل") if requested.empty?

        Product.where(id: requested.map { |item, _| item.product_id }.sort).order(:id).lock.load
        reference = "PR-#{@purchase_order.id}-#{Digest::SHA256.hexdigest(@idempotency_key).first(10).upcase}"
        receipt = @purchase_order.receipts.create!(reference:, received_by: @actor, received_at: @received_at,
          supplier_document_number: @supplier_document_number.to_s.squish.presence, notes: @notes.to_s.squish.presence,
          idempotency_key: @idempotency_key)

        requested.each do |item, quantity|
          product = item.product.reload
          before = product.stock_quantity
          product.update!(stock_quantity: before + quantity)
          movement = product.inventory_movements.create!(actor: @actor, reference: receipt,
            movement_type: :purchase_received, quantity_delta: quantity, quantity_before: before,
            quantity_after: before + quantity, reason: "استلام #{receipt.reference} لأمر الشراء #{@purchase_order.number}",
            idempotency_key: "purchase-receipt:#{receipt.id}:line:#{item.id}")
          receipt.items.create!(purchase_order_item: item, quantity:, unit_cost_cents: item.unit_cost_cents,
            inventory_movement: movement)
          item.update!(received_quantity: item.received_quantity + quantity)
        end

        from = @purchase_order.status
        complete = @purchase_order.items.reload.all? { |item| item.outstanding_quantity.zero? }
        @purchase_order.update!(status: complete ? :received : :partially_received,
          received_at: complete ? @received_at : nil)
        event(@purchase_order, "receipt_posted", from:, to: @purchase_order.status,
          metadata: { receipt_reference: receipt.reference, quantity: requested.sum(&:last) })
        event(@purchase_order, complete ? "fully_received" : "partially_received", from:, to: @purchase_order.status)
        audit(@purchase_order, "purchase_receipt_posted", receipt_reference: receipt.reference,
          quantity: requested.sum(&:last))
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

    def stale!
      raise ActiveRecord::StaleObjectError.new(@purchase_order, "receive") if @lock_version && @purchase_order.lock_version != @lock_version.to_i
    end
    def success(receipt) = Result.new(success?: true, purchase_order: @purchase_order, receipt:, errors: [])
    def failure(receipt, message) = Result.new(success?: false, purchase_order: @purchase_order, receipt:, errors: [ message ])
  end
end
