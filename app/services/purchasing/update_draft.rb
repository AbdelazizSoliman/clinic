module Purchasing
  class UpdateDraft
    include Support
    Result = Data.define(:success?, :purchase_order, :errors)

    def initialize(purchase_order:, actor:, attributes:, lock_version: nil)
      @purchase_order, @actor, @attributes, @lock_version = purchase_order, actor, attributes, lock_version
    end

    def call
      return failure("غير مصرح بإدارة المشتريات") unless @actor&.can_manage_purchasing?
      PurchaseOrder.transaction do
        @purchase_order.lock!
        raise ActiveRecord::StaleObjectError.new(@purchase_order, "update") if @lock_version && @purchase_order.lock_version != @lock_version.to_i
        return failure("يمكن تعديل أمر الشراء في المسودة فقط") unless @purchase_order.draft?
        @purchase_order.update!(@attributes)
        event(@purchase_order, "updated", from: "draft", to: "draft")
        audit(@purchase_order, "purchase_order_updated", @purchase_order.saved_changes.except("updated_at", "lock_version"))
      end
      success
    rescue ActiveRecord::StaleObjectError
      failure("تم تحديث أمر الشراء بواسطة مستخدم آخر؛ أعد تحميل الصفحة")
    rescue ActiveRecord::RecordInvalid => error
      failure(error.record.errors.full_messages.join("، "))
    end

    private

    def success = Result.new(success?: true, purchase_order: @purchase_order, errors: [])
    def failure(message) = Result.new(success?: false, purchase_order: @purchase_order, errors: [ message ])
  end
end
