class WishlistsController < ApplicationController
  before_action :authenticate_user!, only: %i[clear import_browser]

  def show
    if user_signed_in?
      @wishlist_items = current_user.wishlist_items.includes(product: %i[brand category]).order(created_at: :desc)
      @recommendations = Product.active.available.where.not(id: @wishlist_items.map(&:product_id)).featured.limit(4)
      render "wishlists/show"
    else
      @products = Product.includes(:brand, :category).active.order(featured: :desc, name: :asc)
      render "shopping/wishlist"
    end
  end

  def clear
    current_user.wishlist_items.destroy_all
    respond_to do |format|
      format.turbo_stream { render "wishlists/update", locals: { changed_product: nil } }
      format.html { redirect_to wishlist_path, notice: "تم مسح المفضلة", status: :see_other }
    end
  end

  def import_browser
    imported = Wishlists::ImportBrowserWishlist.new(user: current_user, product_ids: params[:product_ids]).call
    render json: { imported:, count: current_user.wishlist_items.count }
  end
end
