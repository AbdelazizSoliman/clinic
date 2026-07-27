module Purchasing
  class RemoveItem
    Result = Data.define(:success?, :errors)
    def initialize(item:, actor:) = (@item, @actor = item, actor)
    def call
      return failure("غير مصرح بإدارة المشتريات") unless @actor&.can_manage_purchasing?
      PurchaseOrder.transaction do
        order = @item.purchase_order
        order.lock!
        return failure("يمكن حذف البنود في المسودة فقط") unless order.draft?
        @item.destroy!
        order.recalculate_totals!
      end
      Result.new(success?: true, errors: [])
    end
    private
    def failure(message) = Result.new(success?: false, errors: [ message ])
  end
end
