module Inventory
  class ChangeQuarantine
    Result = Data.define(:success?, :batch, :errors)

    def initialize(batch:, actor:, quarantined:, reason:, lock_version: nil)
      @batch, @actor, @quarantined, @reason, @lock_version = batch, actor, quarantined, reason, lock_version
    end

    def call
      return failure("غير مصرح بإدارة المخزون") unless @actor&.can_manage_inventory?
      return failure("سبب الإجراء مطلوب") if @reason.blank?
      InventoryBatch.transaction do
        @batch.lock!
        raise ActiveRecord::StaleObjectError.new(@batch, "batch") if @lock_version && @batch.lock_version != @lock_version.to_i
        if @quarantined
          return failure("لا يمكن عزل تشغيلة بها كمية محجوزة") if @batch.reserved_quantity.positive?
          @batch.update!(quarantined_at: Time.current, quarantined_by: @actor, quarantine_reason: @reason.to_s.squish)
          type = "quarantined"
        else
          @batch.update!(quarantined_at: nil, quarantined_by: nil, quarantine_reason: nil)
          type = "quarantine_released"
        end
        @batch.events.create!(actor: @actor, event_type: type, reason: @reason.to_s.squish)
        AdminAuditEvent.create!(actor: @actor, auditable: @batch, action: "inventory_batch_#{type}",
          change_data: { reason: @reason.to_s.squish })
      end
      Result.new(success?: true, batch: @batch, errors: [])
    rescue ActiveRecord::StaleObjectError
      failure("تم تحديث التشغيلة بواسطة مستخدم آخر")
    end

    private

    def failure(message) = Result.new(success?: false, batch: @batch, errors: [ message ])
  end
end
