class HomeController < ApplicationController
  def index
    @categories = Category.active.order(:position, :id).limit(6)
    @featured_products = Product.includes(:brand, :category).featured.limit(8)
    @offer_products = Product.includes(:brand, :category).discounted.limit(8)
  end
end
