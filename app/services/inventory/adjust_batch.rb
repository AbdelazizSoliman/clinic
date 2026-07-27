module Inventory
  class AdjustBatch
    Result = Data.define(:success?, :batch, :movement, :errors)
    TYPES = %w[manual_increase manual_decrease correction damaged expired system_adjustment batch_loss supplier_replacement].freeze

    def initialize(batch:, actor:, movement_type:, quantity_delta:, reason:, lock_version: nil)
      @batch, @actor, @movement_type, @reason, @lock_version = batch, actor, movement_type.to_s, reason, lock_version
      @quantity_delta = Integer(quantity_delta, exception: false)
    end

    def call
      return failure("غير مصرح بإدارة المخزون") unless @actor&.can_manage_inventory?
      return failure("نوع الحركة غير مسموح") unless TYPES.include?(@movement_type)
      return failure("الكمية يجب ألا تساوي صفرًا") unless @quantity_delta&.nonzero?
      return failure("سبب الحركة مطلوب") if @reason.blank?
      return failure("لا يمكن زيادة تشغيلة منتهية أو محجوزة للجودة") if @quantity_delta.positive? && (@batch.expired? || @batch.quarantined?)

      movement = nil
      InventoryBatch.transaction do
        @batch.lock!
        raise ActiveRecord::StaleObjectError.new(@batch, "batch") if @lock_version && @batch.lock_version != @lock_version.to_i
        after = @batch.on_hand_quantity + @quantity_delta
        return failure("لا يمكن خفض التشغيلة عن الكمية المحجوزة #{@batch.reserved_quantity}") if after < @batch.reserved_quantity
        product = @batch.product
        product.lock!
        product_before = product.stock_quantity
        batch_before = @batch.on_hand_quantity
        @batch.update!(on_hand_quantity: after)
        Inventory::BatchAggregate.sync_product!(product)
        movement = product.inventory_movements.create!(actor: @actor, inventory_batch: @batch,
          movement_type: @movement_type, quantity_delta: @quantity_delta,
          quantity_before: product_before, quantity_after: product.stock_quantity,
          batch_quantity_before: batch_before, batch_quantity_after: after, reference: @batch,
          reason: @reason.to_s.squish)
        @batch.events.create!(actor: @actor, event_type: "adjusted", reason: @reason.to_s.squish,
          metadata: { movement_id: movement.id, quantity_delta: @quantity_delta })
        AdminAuditEvent.create!(actor: @actor, auditable: @batch, action: "inventory_batch_adjusted",
          change_data: { movement_id: movement.id, quantity_delta: @quantity_delta })
      end
      Result.new(success?: true, batch: @batch, movement:, errors: [])
    rescue ActiveRecord::StaleObjectError
      failure("تم تحديث التشغيلة بواسطة مستخدم آخر؛ أعد تحميل الصفحة")
    rescue ActiveRecord::RecordInvalid => error
      failure(error.record.errors.full_messages.join("، "))
    end

    private

    def failure(message) = Result.new(success?: false, batch: @batch, movement: nil, errors: [ message ])
  end
end
