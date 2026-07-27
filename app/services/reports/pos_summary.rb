module Reports
  class PosSummary
    Result = Data.define(:cards, :by_cashier, :by_session, :payment_totals, :top_products,
      :discounts, :prescription_items, :reconciliation_differences, :batch_allocations)

    def initialize(range) = @range = range

    def call
      sales = PosSale.completed.where(completed_at: @range.range)
      sessions = CashierSession.closed.where(closed_at: @range.range)
      Result.new(
        cards: {
          sales: sales.count,
          net_cents: sales.sum(:total_cents),
          discounts_cents: sales.sum("automatic_discount_cents + manual_discount_cents"),
          cash_difference_cents: sessions.sum(:cash_difference_cents)
        },
        by_cashier: sales.joins(:cashier).group("users.id", "users.first_name", "users.last_name")
          .sum(:total_cents),
        by_session: sales.joins(:cashier_session).group("cashier_sessions.identifier").sum(:total_cents),
        payment_totals: PosPayment.joins(:pos_sale).merge(sales).group(:payment_method).sum(:amount_cents),
        top_products: PosSaleItem.joins(:pos_sale).merge(sales).group(:product_name)
          .order(Arel.sql("SUM(pos_sale_items.quantity) DESC")).limit(20).sum(:quantity),
        discounts: sales.where("manual_discount_cents > 0").includes(:cashier, :discount_approved_by)
          .order(completed_at: :desc).limit(50),
        prescription_items: PosSaleItem.joins(:pos_sale).merge(sales).where(requires_prescription: true)
          .includes(:pos_sale, :prescription_approved_by).order("pos_sales.completed_at DESC").limit(50),
        reconciliation_differences: sessions.where.not(cash_difference_cents: 0).includes(:user)
          .order(closed_at: :desc).limit(50),
        batch_allocations: PosSaleBatchAllocation.joins(pos_sale_item: :pos_sale).merge(sales)
          .includes(:inventory_batch, pos_sale_item: :pos_sale).order(created_at: :desc).limit(100)
      )
    end
  end
end
