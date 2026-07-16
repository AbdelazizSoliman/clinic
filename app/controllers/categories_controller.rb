class CategoriesController < ApplicationController
  include ProductBrowsing

  def show
    @category = Category.active.find_by!(slug: params[:id])
    load_product_browsing(
      base_relation: @category.products.publicly_available,
      path: category_path(@category),
      locked_category: @category
    )
  end
end
