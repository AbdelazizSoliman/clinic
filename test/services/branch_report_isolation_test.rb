require "test_helper"

class BranchReportIsolationTest < ActiveSupport::TestCase
  test "inventory sales POS purchasing returns and ledgers honor report branch scope" do
    Current.organization = organizations(:default)
    Current.branch_scope = branches(:main)
    range = Reports::DateRange.call({ preset: "current_year" })
    inventory = Reports::InventorySummary.new(range).call
    assert_equal InventoryBatch.where(branch: branches(:main)).sum(:on_hand_quantity), inventory.cards[:physical]
    assert_equal InventoryMovement.where(branch: branches(:main), created_at: range.range).group(:movement_type).sum(:quantity_delta),
      inventory.movement_totals
    assert PosSale.all.all? { |sale| sale.branch_id == branches(:main).id }
    assert PurchaseOrder.all.all? { |order| order.branch_id == branches(:main).id }
    assert ReturnRequest.all.all? { |record| record.branch_id == branches(:main).id }
    assert LoyaltyLedgerEntry.all.all? { |entry| entry.branch_id == branches(:main).id }
    assert WalletLedgerEntry.all.all? { |entry| entry.branch_id == branches(:main).id }
  ensure
    Current.reset
  end
end
