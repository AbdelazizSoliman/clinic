module Purchasing
  class Close
    include Support
    Result = Data.define(:success?, :purchase_order, :errors)
    def initialize(purchase_order:, actor:, lock_version: nil) = (@purchase_order, @actor, @lock_version = purchase_order, actor, lock_version)
    def call
      return failure("غير مصرح بإدارة المشتريات") unless @actor&.can_manage_purchasing?
      PurchaseOrder.transaction do
        @purchase_order.lock!
        raise ActiveRecord::StaleObjectError.new(@purchase_order, "close") if @lock_version && @purchase_order.lock_version != @lock_version.to_i
        return failure("يمكن إغلاق أمر مستلم بالكامل فقط") unless @purchase_order.received?
        @purchase_order.update!(status: :closed, closed_at: Time.current)
        event(@purchase_order, "closed", from: "received", to: "closed")
        audit(@purchase_order, "purchase_order_closed", number: @purchase_order.number)
      end
      success
    rescue ActiveRecord::StaleObjectError
      failure("تم تحديث أمر الشراء بواسطة مستخدم آخر؛ أعد تحميل الصفحة")
    end
    private
    def success = Result.new(success?: true, purchase_order: @purchase_order, errors: [])
    def failure(message) = Result.new(success?: false, purchase_order: @purchase_order, errors: [ message ])
  end
end
