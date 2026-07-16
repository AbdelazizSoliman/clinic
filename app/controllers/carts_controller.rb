class CartsController < ApplicationController
  def show
    @cart = current_cart
    @recommendations = Product.includes(:brand, :category).featured.available.limit(4)
    render "shopping/cart"
  end

  def clear
    current_cart&.items&.destroy_all
    @cart = current_cart
    respond_cart("تم إفراغ سلة التسوق")
  end

  def import_browser
    cart = resolve_cart!
    items = params.permit(items: %i[productId quantity])[:items]
    result = Carts::ImportBrowserCart.new(cart:, items:).call
    render json: { status: result, count: cart.reload.total_quantity }, status: :ok
  rescue ActionController::ParameterMissing
    render json: { error: "بيانات السلة غير صحيحة" }, status: :unprocessable_entity
  end

  private

  def respond_cart(message)
    @cart = current_cart&.reload
    flash.now[:notice] = message
    respond_to do |format|
      format.turbo_stream { render "carts/update" }
      format.html { redirect_to cart_path, notice: message }
    end
  end
end
