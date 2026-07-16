module Reports
  class PromotionPerformance
    Result = Data.define(:campaign_states, :redeemed_count, :released_count, :discount_cents, :orders, :rows)
    def initialize(range) = @range = range
    def call
      redemptions = PromotionRedemption.where(redeemed_at: @range.range)
      rows = OrderPromotion.joins(:order).where(orders: { submitted_at: @range.range })
        .group(:promotion_id, :promotion_name, :code).select(:promotion_id, :promotion_name, :code,
          "COUNT(DISTINCT order_promotions.order_id) AS orders_count", "SUM(order_promotions.discount_cents) AS discount_total_cents",
          "SUM(orders.subtotal_cents) AS gross_cents", "SUM(orders.total_cents) AS net_cents")
        .order(Arel.sql("discount_total_cents DESC"))
      states = Promotion.all.group_by(&:lifecycle_status).transform_values(&:count)
      Result.new(campaign_states: states, redeemed_count: redemptions.redeemed.count,
        released_count: redemptions.released.count, discount_cents: redemptions.redeemed.sum(:discount_cents),
        orders: redemptions.redeemed.distinct.count(:order_id), rows:)
    end
  end
end
