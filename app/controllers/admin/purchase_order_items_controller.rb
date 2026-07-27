module Admin
  class PurchaseOrderItemsController < BaseController
    before_action :set_order
    before_action :set_item, only: %i[update destroy]

    def create
      product = Product.find_by(id: item_params[:product_id])
      result = Purchasing::AddItem.new(purchase_order: @purchase_order, actor: current_user, product:,
        ordered_quantity: item_params[:ordered_quantity], unit_cost_cents: cents(item_params[:unit_cost]), notes: item_params[:notes]).call
      redirect_with(result.success? ? "تمت إضافة المنتج" : result.errors.join("، "), success: result.success?)
    rescue ArgumentError
      redirect_with("تكلفة الوحدة غير صحيحة", success: false)
    end

    def update
      result = Purchasing::UpdateItem.new(item: @item, actor: current_user,
        ordered_quantity: item_params[:ordered_quantity], unit_cost_cents: cents(item_params[:unit_cost]),
        notes: item_params[:notes], lock_version: item_params[:lock_version]).call
      redirect_with(result.success? ? "تم تحديث البند" : result.errors.join("، "), success: result.success?)
    rescue ArgumentError
      redirect_with("تكلفة الوحدة غير صحيحة", success: false)
    end

    def destroy
      result = Purchasing::RemoveItem.new(item: @item, actor: current_user).call
      redirect_with(result.success? ? "تم حذف البند" : result.errors.join("، "), success: result.success?)
    end

    private

    def set_order = @purchase_order = PurchaseOrder.find_by!(number: params[:purchase_order_number])
    def set_item = @item = @purchase_order.items.find(params[:id])
    def item_params = params.require(:purchase_order_item).permit(:product_id, :ordered_quantity, :unit_cost, :notes, :lock_version)
    def cents(value) = (BigDecimal(value.to_s) * 100).round
    def redirect_with(message, success: true)
      redirect_to admin_purchase_order_path(@purchase_order), status: :see_other, flash: { success ? :notice : :alert => message }
    end
  end
end
