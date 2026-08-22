require "test_helper"

class AnalyticsTest < ActiveSupport::TestCase
  test "executive metrics are branch aware and reconcile channels" do
    Current.organization = organizations(:default)
    range = Analytics::DateRange.new(from: 180.days.ago.to_date, to: Date.current)
    metrics = Analytics::ExecutiveSummary.new(range:, branches: [ branches(:main) ]).call
    assert_equal metrics[:online_sales_cents] + metrics[:pos_sales_cents], metrics[:gross_sales_cents]
    assert_equal metrics[:gross_sales_cents] - metrics[:refunds_cents], metrics[:net_sales_cents]
    assert metrics[:branches].all? { |row| row[:id] == branches(:main).id }
  ensure
    Current.reset
  end

  test "date range rejects more than one year" do
    assert_raises(ArgumentError) { Analytics::DateRange.new(from: 2.years.ago.to_date, to: Date.current) }
  end


  test "advanced analytics exposes every operational dataset and safe comparisons" do
    Current.organization = organizations(:default)
    range = Analytics::DateRange.for(preset: "last_30_days")
    result = Analytics::AdvancedSummary.new(range:).call
    assert_equal %i[branches comparison customers inventory loyalty prescriptions purchasing returns safety sales search wallet], result.keys.sort
    assert_equal result.dig(:sales, :gross_cents) - result.dig(:sales, :refunds_cents), result.dig(:sales, :net_cents)
    assert result.dig(:inventory, :available_units) <= result.dig(:inventory, :physical_units)
    result.fetch(:comparison).each_value do |row|
      assert_nil row[:percentage_change] if row[:previous].zero?
    end
  ensure
    Current.reset
  end

  test "branch restricted analytics does not include other branches and hides unbranchable search aggregates" do
    Current.organization = organizations(:default)
    range = Analytics::DateRange.for(preset: "last_30_days")
    result = Analytics::AdvancedSummary.new(range:, branches: [ branches(:main) ]).call
    assert result[:branches].all? { |row| row[:id] == branches(:main).id }
    assert_equal({ restricted: true }, result[:search])
    assert_equal [ branches(:main).id ], result.dig(:inventory, :by_branch).keys
  ensure
    Current.reset
  end

  test "time presets use tenant timezone" do
    Current.organization = organizations(:default)
    today = Analytics::DateRange.for(preset: "today")
    seven = Analytics::DateRange.for(preset: "last_7_days")
    month = Analytics::DateRange.for(preset: "current_month")
    assert_equal today.from.to_date, today.to.to_date
    assert_equal 7, (seven.to.to_date - seven.from.to_date).to_i + 1
    assert_equal month.to.to_date.beginning_of_month, month.from.to_date
    assert_equal "Africa/Cairo", today.timezone
  ensure
    Current.reset
  end
end
