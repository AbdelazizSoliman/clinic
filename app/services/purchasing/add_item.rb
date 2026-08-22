module Purchasing
  class AddItem
    include Support
    Result = Data.define(:success?, :item, :errors)

    def initialize(purchase_order:, actor:, product:, ordered_quantity:, unit_cost_cents:, notes: nil)
      @purchase_order, @actor, @product = purchase_order, actor, product
      @quantity = Integer(ordered_quantity, exception: false)
      @unit_cost = Integer(unit_cost_cents, exception: false)
      @notes = notes
    end

    def call
      return failure(nil, "غير مصرح بإدارة المشتريات") unless @actor&.can_manage_purchasing?
      return failure(nil, "لا يمكن استخدام منتج من مؤسسة أخرى") unless Operations::TenantGuard.same_organization?(
        @purchase_order, @actor, @product)
      return failure(nil, "يمكن تعديل البنود في المسودة فقط") unless @purchase_order.draft?
      return failure(nil, "المنتج غير نشط") unless @product&.active?
      item = nil
      PurchaseOrder.transaction do
        @purchase_order.lock!
        return failure(nil, "يمكن تعديل البنود في المسودة فقط") unless @purchase_order.draft?
        item = @purchase_order.items.create!(product: @product, product_name_snapshot: @product.name,
          sku_snapshot: @product.sku, ordered_quantity: @quantity, unit_cost_cents: @unit_cost,
          line_total_cents: @quantity.to_i * @unit_cost.to_i, notes: @notes)
        @purchase_order.recalculate_totals!
        event(@purchase_order, "updated", from: "draft", to: "draft", metadata: { item_id: item.id })
      end
      Result.new(success?: true, item:, errors: [])
    rescue ActiveRecord::RecordInvalid => error
      failure(item, error.record.errors.full_messages.join("، "))
    end

    private

    def failure(item, message) = Result.new(success?: false, item:, errors: [ message ])
  end
end
