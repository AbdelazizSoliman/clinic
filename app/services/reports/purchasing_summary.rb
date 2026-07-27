module Reports
  class PurchasingSummary
    Result = Data.define(:cards, :supplier_totals, :outstanding, :overdue, :partial,
      :top_products, :latest_costs, :daily_totals)

    def initialize(range) = @range = range
    def call
      receipt_items = PurchaseReceiptItem.joins(:purchase_receipt).where(purchase_receipts: { received_at: @range.range })
      orders = PurchaseOrder.where(ordered_at: @range.range)
      Result.new(
        cards: { orders: orders.count, ordered_cents: orders.sum(:total_cents),
          receipts: PurchaseReceipt.where(received_at: @range.range).count,
          received_cents: receipt_items.sum("purchase_receipt_items.quantity * purchase_receipt_items.unit_cost_cents"),
          outstanding_orders: PurchaseOrder.outstanding.count, overdue_orders: PurchaseOrder.overdue.count },
        supplier_totals: supplier_totals(receipt_items), outstanding: PurchaseOrder.outstanding.includes(:supplier, :items).order(:expected_at),
        overdue: PurchaseOrder.overdue.includes(:supplier, :items).order(:expected_at),
        partial: PurchaseOrder.partially_received.includes(:supplier, :items).order(expected_at: :asc),
        top_products: top_products(receipt_items), latest_costs: latest_costs,
        daily_totals: daily_totals(receipt_items))
    end

    private

    def supplier_totals(scope)
      scope.joins(purchase_receipt: { purchase_order: :supplier }).group("suppliers.id", "suppliers.name")
        .order(Arel.sql("SUM(purchase_receipt_items.quantity * purchase_receipt_items.unit_cost_cents) DESC"))
        .sum("purchase_receipt_items.quantity * purchase_receipt_items.unit_cost_cents")
    end

    def top_products(scope)
      scope.joins(purchase_order_item: :product).group("products.id", "purchase_order_items.product_name_snapshot")
        .order(Arel.sql("SUM(purchase_receipt_items.quantity) DESC")).limit(20).sum(:quantity)
    end

    def latest_costs
      PurchaseReceiptItem.joins(:purchase_receipt, purchase_order_item: :product)
        .select("DISTINCT ON (products.id) products.id AS product_id, purchase_order_items.product_name_snapshot, purchase_receipt_items.unit_cost_cents, purchase_receipts.received_at")
        .order(Arel.sql("products.id, purchase_receipts.received_at DESC"))
    end

    def daily_totals(scope)
      scope.group(Arel.sql("DATE(purchase_receipts.received_at AT TIME ZONE 'UTC' AT TIME ZONE 'Africa/Cairo')"))
        .order(Arel.sql("DATE(purchase_receipts.received_at AT TIME ZONE 'UTC' AT TIME ZONE 'Africa/Cairo')"))
        .sum("purchase_receipt_items.quantity * purchase_receipt_items.unit_cost_cents")
    end
  end
end
