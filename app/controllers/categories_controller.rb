class CategoriesController < ApplicationController
  def show
    @category = Category.find_by!(slug: params[:id])
    @products = @category.products.includes(:brand).active.order(featured: :desc, name: :asc)
  end
end
