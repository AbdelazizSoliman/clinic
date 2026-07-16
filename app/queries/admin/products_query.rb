module Admin
  class ProductsQuery
    AVAILABLE_SQL = "products.stock_quantity - COALESCE((SELECT SUM(ir.quantity) FROM inventory_reservations ir WHERE ir.product_id = products.id AND ir.status = 0), 0)".freeze
    SORTS = { "name" => { name: :asc }, "newest" => { created_at: :desc }, "updated" => { updated_at: :desc }, "price" => { price: :asc }, "stock" => { stock_quantity: :asc } }.freeze
    def initialize(relation, params) = (@relation, @params = relation, params)
    def call
      scope = @relation
      if @params[:q].present?
        term = "%#{Product.sanitize_sql_like(@params[:q])}%"
        scope = scope.where("products.name ILIKE :term OR products.sku ILIKE :term OR products.barcode ILIKE :term", term:)
      end
      scope = scope.where(category_id: @params[:category_id]) if @params[:category_id].present?
      scope = scope.where(brand_id: @params[:brand_id]) if @params[:brand_id].present?
      scope = scope.where(active: @params[:active] == "true") if %w[true false].include?(@params[:active])
      scope = scope.where(featured: true) if @params[:featured] == "true"
      scope = scope.where(requires_prescription: true) if @params[:prescription] == "true"
      scope = scope.where(cold_chain_required: true) if @params[:cold_chain] == "true"
      scope = scope.where("compare_at_price > price") if @params[:discounted] == "true"
      scope = scope.where("#{AVAILABLE_SQL} <= 0") if @params[:out_of_stock] == "true"
      scope = scope.where("#{AVAILABLE_SQL} > 0 AND #{AVAILABLE_SQL} <= products.low_stock_threshold") if @params[:low_stock] == "true"
      return scope.order(Arel.sql("#{AVAILABLE_SQL} ASC"), id: :asc) if @params[:sort] == "available"
      return scope.order(Arel.sql("(#{AVAILABLE_SQL} - products.low_stock_threshold) ASC"), id: :asc) if @params[:sort] == "low_stock"

      scope.order(SORTS.fetch(@params[:sort], SORTS["updated"]))
    end
  end
end
