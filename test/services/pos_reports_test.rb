require "test_helper"

class PosReportsTest < ActiveSupport::TestCase
  test "summary and CSV use completed sales in the Cairo-aware range" do
    cashier = users(:order_manager)
    session = Pos::OpenSession.new(actor: cashier, opening_cash_cents: 0, identifier: "REPORT-SHIFT").call.record
    sale = session.pos_sales.create!(cashier:, number: "POS-REPORT")
    Pos::Cart.new(sale:, actor: cashier).add(product: products(:featured), quantity: 2)
    Pos::Complete.new(sale:, actor: cashier, idempotency_key: "pos-report",
      payments: [ { payment_method: "cash", amount_cents: sale.total_cents, tendered_cents: sale.total_cents } ]).call
    range = Reports::DateRange.call({ preset: "today" })
    report = Reports::PosSummary.new(range).call
    assert_equal 1, report.cards[:sales]
    assert_equal sale.reload.total_cents, report.cards[:net_cents]
    assert_equal 2, report.top_products[products(:featured).name]
    assert_equal sale.total_cents, report.payment_totals["cash"]
    export = Reports::ExportRows.call("pos", range)
    assert_equal 1, export.rows.size
    assert_equal "POS-REPORT", export.rows.first.first
  end
end
