module Purchasing
  class Cancel
    include Support
    Result = Data.define(:success?, :purchase_order, :errors)
    ALLOWED = %w[draft submitted approved partially_received].freeze

    def initialize(purchase_order:, actor:, reason:, lock_version: nil)
      @purchase_order, @actor, @reason, @lock_version = purchase_order, actor, reason, lock_version
    end

    def call
      return failure("غير مصرح بإدارة المشتريات") unless @actor&.can_manage_purchasing?
      return failure("سبب الإلغاء مطلوب") if @reason.blank?
      PurchaseOrder.transaction do
        @purchase_order.lock!
        raise ActiveRecord::StaleObjectError.new(@purchase_order, "cancel") if @lock_version && @purchase_order.lock_version != @lock_version.to_i
        return success if @purchase_order.cancelled?
        return failure("لا يمكن إلغاء أمر الشراء في حالته الحالية") unless ALLOWED.include?(@purchase_order.status)
        from = @purchase_order.status
        @purchase_order.update!(status: :cancelled, cancelled_at: Time.current, cancelled_by: @actor,
          cancellation_reason: @reason.to_s.squish)
        event(@purchase_order, "cancelled", from:, to: "cancelled", metadata: { received_quantity: @purchase_order.items.sum(:received_quantity) })
        audit(@purchase_order, "purchase_order_cancelled", number: @purchase_order.number)
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
