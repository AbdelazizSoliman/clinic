module ProductBrowsing
  extend ActiveSupport::Concern

  BROWSING_KEYS = %i[q category brand min_price max_price discounted available prescription featured sort page].freeze

  private

  def load_product_browsing(base_relation:, path:, locked_category: nil)
    query_params = browsing_params.to_h
    query_params["category"] = locked_category.slug if locked_category
    @products_query = ProductsQuery.new(base_relation, query_params)
    @pagy, @products = pagy(:offset, @products_query.call.includes(:brand, :category), limit: 12)
    @categories = Category.active.order(:position, :name)
    @brands = Brand.active.joins(:products).where(products: { id: base_relation.reselect(:id) }).distinct.order(:name)
    @browsing_path = path
    @locked_category = locked_category
    @active_browsing_params = browsing_params.to_h.except("page")
  end

  def browsing_params
    params.permit(*BROWSING_KEYS)
  end
end
