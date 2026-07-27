module Purchasing
  class Submit
    include Support
    Result = Data.define(:success?, :purchase_order, :errors)
    def initialize(purchase_order:, actor:, lock_version: nil) = (@purchase_order, @actor, @lock_version = purchase_order, actor, lock_version)
    def call
      return failure("غير مصرح بإدارة المشتريات") unless @actor&.can_manage_purchasing?
      PurchaseOrder.transaction do
        @purchase_order.lock!
        stale!
        return failure("يمكن إرسال المسودة فقط") unless @purchase_order.draft?
        return failure("لا يمكن إرسال أمر شراء فارغ") unless @purchase_order.items.exists?
        return failure("المورد غير نشط") unless @purchase_order.supplier.active?
        @purchase_order.items.find_each do |item|
          item.update!(product_name_snapshot: item.product.name, sku_snapshot: item.product.sku)
        end
        @purchase_order.recalculate_totals!
        @purchase_order.update!(status: :submitted, submitted_at: Time.current, ordered_at: @purchase_order.ordered_at || Time.current)
        event(@purchase_order, "submitted", from: "draft", to: "submitted")
        audit(@purchase_order, "purchase_order_submitted", number: @purchase_order.number)
        notify(User.where(active: true, role: :admin), @purchase_order, "purchase_order_submitted",
          "أمر شراء بانتظار الاعتماد", "purchase-order-submitted:#{@purchase_order.id}")
      end
      success
    rescue ActiveRecord::StaleObjectError
      failure("تم تحديث أمر الشراء بواسطة مستخدم آخر؛ أعد تحميل الصفحة")
    rescue ActiveRecord::RecordInvalid => error
      failure(error.record.errors.full_messages.join("، "))
    end
    private
    def stale!
      raise ActiveRecord::StaleObjectError.new(@purchase_order, "submit") if @lock_version && @purchase_order.lock_version != @lock_version.to_i
    end
    def success = Result.new(success?: true, purchase_order: @purchase_order, errors: [])
    def failure(message) = Result.new(success?: false, purchase_order: @purchase_order, errors: [ message ])
  end
end
