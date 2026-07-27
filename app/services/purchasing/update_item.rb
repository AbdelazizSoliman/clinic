module Purchasing
  class UpdateItem
    Result = Data.define(:success?, :item, :errors)

    def initialize(item:, actor:, ordered_quantity:, unit_cost_cents:, notes: nil, lock_version: nil)
      @item, @actor, @notes, @lock_version = item, actor, notes, lock_version
      @quantity = Integer(ordered_quantity, exception: false)
      @unit_cost = Integer(unit_cost_cents, exception: false)
    end

    def call
      return failure("غير مصرح بإدارة المشتريات") unless @actor&.can_manage_purchasing?
      PurchaseOrder.transaction do
        order = @item.purchase_order
        order.lock!
        @item.lock!
        raise ActiveRecord::StaleObjectError.new(@item, "update") if @lock_version && @item.lock_version != @lock_version.to_i
        return failure("يمكن تعديل البنود في المسودة فقط") unless order.draft?
        @item.update!(ordered_quantity: @quantity, unit_cost_cents: @unit_cost,
          line_total_cents: @quantity.to_i * @unit_cost.to_i, notes: @notes)
        order.recalculate_totals!
      end
      Result.new(success?: true, item: @item, errors: [])
    rescue ActiveRecord::StaleObjectError
      failure("تم تحديث البند بواسطة مستخدم آخر؛ أعد تحميل الصفحة")
    rescue ActiveRecord::RecordInvalid => error
      failure(error.record.errors.full_messages.join("، "))
    end

    private

    def failure(message) = Result.new(success?: false, item: @item, errors: [ message ])
  end
end
