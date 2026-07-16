module Reports
  class SalesSummary
    REALIZED = %w[confirmed preparing ready_for_delivery out_for_delivery delivered].freeze
    PIPELINE = %w[pending_prescription submitted].freeze
    Result = Data.define(:cards, :status_counts, :series, :zone_breakdown, :method_breakdown)
    def initialize(range) = @range = range
    def call
      scope = Order.where(submitted_at: @range.range)
      realized = scope.where(status: REALIZED)
      cards = {
        submitted_orders: scope.count, confirmed_orders: realized.count, delivered_orders: scope.delivered.count,
        gross_cents: realized.sum(:subtotal_cents), discount_cents: realized.sum(:discount_cents),
        delivery_cents: realized.sum(:delivery_fee_cents) - realized.sum(:delivery_discount_cents),
        net_cents: realized.sum(:total_cents), average_cents: realized.average(:total_cents).to_i,
        pipeline_cents: scope.where(status: PIPELINE).sum(:total_cents), cancelled_cents: scope.cancelled.sum(:total_cents),
        rejected_cents: scope.rejected.sum(:total_cents)
      }
      Result.new(cards:, status_counts: scope.group(:status).count,
        series: daily_series(realized), zone_breakdown: realized.group(:delivery_zone_name).sum(:total_cents),
        method_breakdown: realized.group(:delivery_method_name).sum(:total_cents))
    end
    private
    def daily_series(scope)
      scope.group(Arel.sql("DATE(submitted_at AT TIME ZONE 'UTC' AT TIME ZONE 'Africa/Cairo')"))
        .pluck(Arel.sql("DATE(submitted_at AT TIME ZONE 'UTC' AT TIME ZONE 'Africa/Cairo')"), Arel.sql("COUNT(*)"), Arel.sql("SUM(subtotal_cents)"), Arel.sql("SUM(total_cents)"))
    end
  end
end
