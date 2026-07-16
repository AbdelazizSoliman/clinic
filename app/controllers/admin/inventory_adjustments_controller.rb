module Admin
  class InventoryAdjustmentsController < BaseController
    def index
      scope = InventoryMovement.includes(:product, :actor).order(created_at: :desc)
      scope = scope.where(product_id: params[:product_id]) if params[:product_id].present?
      scope = scope.where(movement_type: params[:movement_type]) if InventoryMovement.movement_types.key?(params[:movement_type])
      @pagy, @movements = pagy(scope, limit: 30)
    end
    def show = @movement = InventoryMovement.includes(:product, :actor).find(params[:id])
    def new = @product = Product.find(params[:product_id])
    def create
      @product = Product.find(params[:product_id])
      result = Inventory::AdjustStock.new(product: @product, actor: current_user, movement_type: params[:movement_type],
        quantity_delta: signed_delta, reason: params[:reason], lock_version: params[:lock_version]).call
      redirect_to admin_product_path(@product), status: :see_other, flash: { result.success? ? :notice : :alert => result.success? ? "تم تعديل المخزون وتسجيل الحركة" : result.errors.join("، ") }
    end
    private
    def signed_delta
      amount = Integer(params[:quantity], exception: false).to_i.abs
      %w[manual_decrease damaged expired].include?(params[:movement_type]) ? -amount : amount
    end
  end
end
