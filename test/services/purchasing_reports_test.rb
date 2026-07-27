require "test_helper"

class PurchasingReportsTest < ActiveSupport::TestCase
  setup do
    @supplier = Supplier.create!(name: "مورد التقارير", code: "REPORT-SUP")
    @order = Purchasing::CreateOrder.new(actor: users(:inventory_manager), supplier: @supplier,
      attributes: { expected_at: Date.yesterday }).call.purchase_order
    @item = Purchasing::AddItem.new(purchase_order: @order, actor: users(:inventory_manager), product: products(:featured),
      ordered_quantity: 4, unit_cost_cents: 250).call.item
    Purchasing::Submit.new(purchase_order: @order, actor: users(:inventory_manager)).call
    Purchasing::Approve.new(purchase_order: @order.reload, actor: users(:admin)).call
    Purchasing::Receive.new(purchase_order: @order.reload, actor: users(:inventory_manager), quantities: { @item.id => 1 },
      idempotency_key: "report-receipt").call
    @range = Reports::DateRange.call({ preset: "last_30_days" })
  end

  test "summary exposes supplier totals outstanding overdue partial and latest cost" do
    report = Reports::PurchasingSummary.new(@range).call
    assert_equal 1, report.cards[:receipts]
    assert_equal 250, report.cards[:received_cents]
    assert_equal 250, report.supplier_totals.values.first
    assert_includes report.outstanding, @order.reload
    assert_includes report.overdue, @order
    assert_includes report.partial, @order
    assert_equal 250, report.latest_costs.first.unit_cost_cents
  end

  test "CSV contains received purchase history" do
    export = Reports::ExportRows.call("purchasing", @range)
    assert_equal 1, export.rows.size
    assert_equal @order.number, export.rows.first[1]
    assert_equal 250, export.rows.first[7]
  end
end
