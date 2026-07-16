class WishlistItemsController < ApplicationController
  before_action :authenticate_user!

  def create
    @product = Product.active.find_by(id: params.dig(:wishlist_item, :product_id))
    return respond_error("المنتج غير متاح للحفظ") unless @product

    current_user.wishlist_items.find_or_create_by!(product: @product)
    respond_change("تمت إضافة المنتج إلى المفضلة")
  end

  def destroy
    item = current_user.wishlist_items.find(params[:id])
    @product = item.product
    item.destroy!
    respond_change("تمت إزالة المنتج من المفضلة")
  end

  private

  def respond_change(message)
    flash.now[:notice] = message
    respond_to do |format|
      format.turbo_stream { render "wishlists/update", locals: { changed_product: @product } }
      format.html { redirect_back fallback_location: wishlist_path, notice: message, status: :see_other }
    end
  end

  def respond_error(message)
    respond_to do |format|
      format.turbo_stream { redirect_to wishlist_path, alert: message, status: :see_other }
      format.html { redirect_back fallback_location: wishlist_path, alert: message, status: :see_other }
    end
  end
end
