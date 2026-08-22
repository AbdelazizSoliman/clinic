require "test_helper"

class PlatformIntegrityChecksTest < ActiveSupport::TestCase
  test "tenant integrity is clean and read only" do
    counts = [ Organization.unscoped.count, Product.unscoped.count, Order.unscoped.count ]
    assert_empty Operations::TenantIntegrityCheck.new.call
    assert_equal counts, [ Organization.unscoped.count, Product.unscoped.count, Order.unscoped.count ]
  end

  test "inventory integrity is clean" do
    assert_empty Operations::InventoryIntegrityCheck.new.call
  end

  test "financial integrity is clean" do
    assert_empty Operations::FinancialIntegrityCheck.new.call
  end
end
