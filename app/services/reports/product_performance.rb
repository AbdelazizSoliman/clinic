module Reports
  class ProductPerformance
    REALIZED = Reports::SalesSummary::REALIZED
    def initialize(range) = @range = range
    def call
      OrderItem.joins(:order).where(orders: { submitted_at: @range.range, status: REALIZED })
        .group(:product_id, :product_name, :brand_name, :category_name)
        .select(:product_id, :product_name, :brand_name, :category_name,
          "SUM(order_items.quantity) AS units_sold", "SUM(order_items.line_total_cents) AS net_cents",
          "SUM(COALESCE(order_items.original_unit_price_cents, order_items.unit_price_cents) * order_items.quantity) AS gross_cents",
          "SUM(order_items.discount_cents) AS discount_cents", "COUNT(DISTINCT order_items.order_id) AS order_count")
        .order(Arel.sql("SUM(order_items.quantity) DESC, order_items.product_name ASC"))
    end
  end
end
