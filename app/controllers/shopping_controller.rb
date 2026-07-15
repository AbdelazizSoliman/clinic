class ShoppingController < ApplicationController
  def cart
    @recommendations = Product.includes(:brand, :category).featured.available.limit(4)
  end

  def wishlist
    @products = Product.includes(:brand, :category).active.order(featured: :desc, name: :asc)
  end

  def checkout
    @recommendations = Product.includes(:brand, :category).discounted.available.limit(4)
  end
end
