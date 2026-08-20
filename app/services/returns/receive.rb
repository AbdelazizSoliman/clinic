module Returns
  class Receive
    include Support
    def initialize(return_request:, actor:, dispositions:, idempotency_key:)
      @request, @actor, @dispositions, @key = return_request, actor, dispositions.to_h.stringify_keys, idempotency_key.to_s
    end

    def call
      return failure(@request, "غير مصرح بتنفيذ قرار المخزون") unless @actor&.can_disposition_returns?
      return failure(@request, "مفتاح العملية مطلوب") if @key.blank?
      ReturnRequest.transaction do
        @request.lock!
        return success(@request) if @request.received? || @request.refunded? || @request.closed?
        raise ActiveRecord::RecordInvalid, @request unless @request.approved?
        @request.items.includes(:source_item).order(:id).lock.each { |item| receive_item!(item) }
        @request.update!(status: :received, received_at: Time.current)
        audit(@actor, @request, "return_received", idempotency_key: @key)
      end
      success(@request)
    rescue ActiveRecord::RecordInvalid => error
      failure(@request, error.record.errors.full_messages)
    rescue ActiveRecord::RecordNotUnique
      @request.reload.received? ? success(@request) : failure(@request, "تعارض في تنفيذ المرتجع")
    end

    private

    def receive_item!(item)
      disposition = item.disposition || @dispositions[item.id.to_s]
      item.disposition = disposition
      item.received_quantity = item.approved_quantity
      item.validate!
      if item.pharmacist_inspection_required? && item.inspected_at.nil?
        item.errors.add(:base, "يلزم فحص الصيدلي قبل استلام الدواء")
        raise ActiveRecord::RecordInvalid, item
      end
      allocations_for(item).each do |original|
        remaining = item.received_quantity - item.batch_allocations.sum(:quantity)
        break unless remaining.positive?
        used = ReturnItemBatchAllocation.where(original_allocation: original).sum(:quantity)
        quantity = [ remaining, original.quantity - used ].min
        next unless quantity.positive?
        post_allocation!(item, original, quantity, disposition)
      end
      if item.batch_allocations.sum(:quantity) != item.received_quantity
        item.errors.add(:received_quantity, "تتجاوز الكمية المتبقية في تخصيصات التشغيلات الأصلية")
        raise ActiveRecord::RecordInvalid, item
      end
      item.save!
      audit(@actor, @request, "return_item_received", return_item_id: item.id, quantity: item.received_quantity)
    end

    def allocations_for(item)
      if item.source_item_type == "OrderItem"
        ids = item.source_item.inventory_reservations.consumed.joins(:reservation_allocations)
          .pluck("inventory_reservation_allocations.id")
        InventoryReservationAllocation.where(id: ids).order(:id).lock.to_a
      else
        item.source_item.batch_allocations.order(:id).lock.to_a
      end
    end

    def post_allocation!(item, original, quantity, disposition)
      batch = original.inventory_batch
      batch.lock!
      product = batch.product
      product.lock!
      validate_disposition!(item, batch, disposition)
      product_before = product.stock_quantity
      batch_before = batch.on_hand_quantity
      delta = %w[restock quarantine].include?(disposition) ? quantity : 0
      attrs = { on_hand_quantity: batch_before + delta }
      attrs[:returned_quarantine_quantity] = batch.returned_quarantine_quantity + quantity if disposition == "quarantine"
      batch.update!(attrs)
      Inventory::BatchAggregate.sync_product!(product)
      movement = product.inventory_movements.create!(actor: @actor, inventory_batch: batch, reference: item,
        movement_type: "return_#{disposition}", return_movement: true, quantity_delta: delta,
        quantity_before: product_before, quantity_after: product.stock_quantity,
        batch_quantity_before: batch_before, batch_quantity_after: batch.on_hand_quantity,
        reason: "مرتجع #{@request.number} — #{disposition}",
        idempotency_key: "return:#{@request.id}:#{@key}:item:#{item.id}:original:#{original.class.name}:#{original.id}")
      item.batch_allocations.create!(original_allocation: original, inventory_batch: batch,
        inventory_movement: movement, quantity:, disposition:,
        idempotency_key: "return-allocation:#{@request.id}:item:#{item.id}:original:#{original.class.name}:#{original.id}")
      audit(@actor, @request, "return_#{disposition}", return_item_id: item.id, batch_id: batch.id, quantity:)
    end

    def validate_disposition!(item, batch, disposition)
      unless ReturnItem.dispositions.key?(disposition)
        item.errors.add(:disposition, "غير صالح")
        raise ActiveRecord::RecordInvalid, item
      end
      return unless disposition == "restock"
      if !item.condition_unopened? || batch.expired? || batch.quarantined?
        item.errors.add(:disposition, "لا يمكن إعادة هذا البند إلى المخزون المتاح")
        raise ActiveRecord::RecordInvalid, item
      end
    end
  end
end
