class ProductsController < ApplicationController
  include ProductBrowsing

  before_action :set_product, only: :show

  def index
    load_product_browsing(base_relation: Product.active, path: products_path)
  end

  def show
    @related_products = Product.includes(:brand).active.where(category: @product.category).where.not(id: @product.id).limit(4)
    category_products = Product.active.where(category: @product.category).order(:name)
    @previous_product = category_products.where("name < ?", @product.name).last
    @next_product = category_products.where("name > ?", @product.name).first
  end

  private

  def set_product
    @product = Product.active.includes(:brand, :category).find_by!(slug: params[:id])
  end
end
