class CartItemsController < ApplicationController
  before_action :set_owned_item, only: %i[update destroy]

  def create
    cart = resolve_cart!
    product = Product.find_by(id: cart_item_params[:product_id])
    result = Carts::SetItemQuantity.new(cart:, product:, quantity: cart_item_params[:quantity], additive: true).call
    @changed_product = product
    respond_result(result)
  end

  def update
    result = Carts::SetItemQuantity.new(cart: current_cart, product: @item.product, quantity: cart_item_params[:quantity]).call
    @changed_product = @item.product
    respond_result(result)
  end

  def destroy
    @changed_product = @item.product
    @item.destroy!
    respond_result(Carts::SetItemQuantity::Result.new(success?: true, item: nil, message: "تمت إزالة المنتج من السلة", notice: nil))
  end

  private

  def set_owned_item
    @item = current_cart&.items&.find_by(id: params[:id])
    return if @item

    head :not_found
  end

  def cart_item_params
    params.require(:cart_item).permit(:product_id, :quantity)
  end

  def respond_result(result)
    @cart = current_cart&.reload
    flash.now[result.success? ? :notice : :alert] = result.message
    flash.now[:notice] = "#{result.message}. #{result.notice}" if result.notice
    status = result.success? ? :ok : :unprocessable_entity
    respond_to do |format|
      format.turbo_stream { render "carts/update", status: }
      format.html { redirect_back fallback_location: cart_path, status: :see_other, flash: { result.success? ? :notice : :alert => result.message } }
    end
  end
end
