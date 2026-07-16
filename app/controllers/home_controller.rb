class HomeController < ApplicationController
  def index
    @categories = Category.active.order(:position, :id).limit(6)
    preload = { images: { file_attachment: :blob } }
    @featured_products = Product.includes(:brand, :category, :inventory_reservations, preload).featured.limit(8)
    @offer_products = Product.includes(:brand, :category, :inventory_reservations, preload).discounted.limit(8)
  end
end
