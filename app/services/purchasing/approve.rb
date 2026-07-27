module Purchasing
  class Approve
    include Support
    Result = Data.define(:success?, :purchase_order, :errors)
    def initialize(purchase_order:, actor:, lock_version: nil) = (@purchase_order, @actor, @lock_version = purchase_order, actor, lock_version)
    def call
      return failure("اعتماد أوامر الشراء متاح للمدير فقط") unless @actor&.can_approve_purchasing?
      PurchaseOrder.transaction do
        @purchase_order.lock!
        raise ActiveRecord::StaleObjectError.new(@purchase_order, "approve") if @lock_version && @purchase_order.lock_version != @lock_version.to_i
        return failure("يمكن اعتماد أمر مرسل فقط") unless @purchase_order.submitted?
        return failure("لا يمكن اعتماد أمر شراء فارغ") unless @purchase_order.items.exists?
        return failure("المورد غير نشط") unless @purchase_order.supplier.active?
        return failure("بعض المنتجات غير صالحة") unless @purchase_order.items.all?(&:valid?)
        @purchase_order.update!(status: :approved, approved_by: @actor, approved_at: Time.current)
        event(@purchase_order, "approved", from: "submitted", to: "approved")
        audit(@purchase_order, "purchase_order_approved", number: @purchase_order.number)
        notify(User.where(active: true, role: :inventory_manager), @purchase_order, "purchase_order_approved",
          "تم اعتماد أمر شراء", "purchase-order-approved:#{@purchase_order.id}")
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
