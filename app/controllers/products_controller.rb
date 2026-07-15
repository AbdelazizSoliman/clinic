class ProductsController < ApplicationController
  before_action :set_product, only: :show

  def index
    @products = Product.includes(:brand, :category).active.order(created_at: :desc)
    @products = @products.where("products.name ILIKE :query OR products.short_description ILIKE :query", query: "%#{Product.sanitize_sql_like(params[:q])}%") if params[:q].present?
  end

  def show
    @related_products = Product.includes(:brand).active.where(category: @product.category).where.not(id: @product.id).limit(4)
  end

  private

  def set_product
    @product = Product.active.includes(:brand, :category).find_by!(slug: params[:id])
  end
end
