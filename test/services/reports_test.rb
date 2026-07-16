require "test_helper"

class ReportsTest < ActiveSupport::TestCase
  test "date range uses Cairo boundaries and an exclusive UTC end" do
    now = ActiveSupport::TimeZone["Africa/Cairo"].local(2026, 7, 16, 12)
    range = Reports::DateRange.call({ preset: "today" }, now:)

    assert range.valid?
    assert_equal Time.utc(2026, 7, 15, 21), range.start_at
    assert_equal Time.utc(2026, 7, 16, 21), range.end_at
    assert_equal 1, range.days
  end

  test "custom date ranges reject invalid and excessive inputs" do
    invalid = Reports::DateRange.call({ preset: "custom", from: "bad", to: "2026-07-16" })
    excessive = Reports::DateRange.call({ preset: "custom", from: "2024-01-01", to: "2026-07-16" })

    assert_not invalid.valid?
    assert_equal "invalid_date", invalid.error
    assert_not excessive.valid?
    assert_equal "range_too_large", excessive.error
  end

  test "CSV exporter emits BOM, quotes Arabic and neutralizes spreadsheet formulas" do
    result = Reports::CsvExporter.call(headers: [ "الاسم" ], rows: [ [ "=2+2" ], [ "+cmd" ], [ "آمن" ] ])

    assert result.content.start_with?(Reports::CsvExporter::BOM)
    assert_includes result.content, %q("'=2+2")
    assert_includes result.content, %q("'+cmd")
    assert_includes result.content, %q("آمن")
    assert_equal 3, result.row_count
  end

  test "sales summary excludes pipeline and terminal orders from realized revenue" do
    range = Reports::DateRange.call({ preset: "current_year" })
    realized = create_report_order(status: :delivered, subtotal_cents: 10_000, discount_cents: 1_000,
      delivery_fee_cents: 500, delivery_discount_cents: 100, total_cents: 9_400)
    create_report_order(status: :submitted, subtotal_cents: 20_000, total_cents: 20_000)
    create_report_order(status: :cancelled, subtotal_cents: 30_000, total_cents: 30_000,
      cancellation_reason: "اختبار", cancellation_source: :customer, cancelled_at: Time.current,
      cancelled_by: users(:customer))

    report = Reports::SalesSummary.new(range).call

    assert_equal 3, report.cards[:submitted_orders]
    assert_equal 1, report.cards[:delivered_orders]
    assert_equal realized.subtotal_cents, report.cards[:gross_cents]
    assert_equal 1_000, report.cards[:discount_cents]
    assert_equal 400, report.cards[:delivery_cents]
    assert_equal 9_400, report.cards[:net_cents]
    assert_equal 20_000, report.cards[:pipeline_cents]
    assert_equal 30_000, report.cards[:cancelled_cents]
  end

  test "export audit is append only" do
    event = ReportExportEvent.create!(user: users(:admin), report_type: "sales", range_start: 1.day.ago,
      range_end: Time.current, row_count: 2)

    assert_not event.update(row_count: 3)
    assert_not event.destroy
  end

  private

  def create_report_order(attributes)
    defaults = {
      user: users(:customer), cart: Cart.create!(user: users(:customer), status: :completed, currency: "EGP"),
      number: "PH-#{SecureRandom.hex(5).upcase}", status: :submitted, payment_method: :cash_on_delivery,
      payment_status: :unpaid, currency: "EGP", subtotal_cents: 0, discount_cents: 0,
      product_discount_cents: 0, cart_discount_cents: 0, delivery_discount_cents: 0,
      delivery_fee_cents: 0, total_cents: 0, customer_email: users(:customer).email,
      customer_mobile_number: users(:customer).mobile_number, customer_first_name: "أحمد",
      customer_last_name: "محمد", delivery_method: "standard", prescription_required: false,
      submitted_at: Time.current
    }
    Order.create!(defaults.merge(attributes))
  end
end
