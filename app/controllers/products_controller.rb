class ProductsController < ApplicationController
  include ProductBrowsing

  before_action :set_product, only: :show

  def index
    load_product_browsing(base_relation: Product.publicly_available, path: products_path)
  end

  def show
    @related_products = Product.includes(:brand).publicly_available.where(category: @product.category).where.not(id: @product.id).limit(4)
    category_products = Product.publicly_available.where(category: @product.category).order(:name)
    @previous_product = category_products.where("products.name < ?", @product.name).last
    @next_product = category_products.where("products.name > ?", @product.name).first
    @recent_candidates = Product.includes(:brand).publicly_available.where.not(id: @product.id).limit(24)
  end

  private

  def set_product
    @product = Product.publicly_available.includes(:brand, :category).find_by!(slug: params[:id])
  end
end
