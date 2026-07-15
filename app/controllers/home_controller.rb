class HomeController < ApplicationController
  def index
    @categories = Category.order(:id).limit(6)
    @featured_products = Product.includes(:brand, :category).featured.limit(8)
    @offer_products = Product.includes(:brand, :category).discounted.limit(8)
  end
end
