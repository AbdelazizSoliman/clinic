class ShoppingController < ApplicationController
  def wishlist
    @products = Product.includes(:brand, :category).active.order(featured: :desc, name: :asc)
  end

  def checkout
    @cart = current_cart
    @recommendations = Product.includes(:brand, :category).discounted.available.limit(4)
  end
end
