require "test_helper"

class ReturnsTest < ActiveSupport::TestCase
  setup do
    @cashier = users(:order_manager)
    @admin = users(:admin)
    @inventory_manager = users(:inventory_manager)
    @product = products(:featured)
    @session = Pos::OpenSession.new(actor: @cashier, opening_cash_cents: 10_000,
      identifier: "RETURN-SALE-SHIFT").call.record
  end

  test "partial POS return restores original batches and retry is idempotent" do
    first = inventory_batches(:featured_primary)
    first.update_columns(on_hand_quantity: 2, original_quantity: 2, expiry_date: 1.month.from_now)
    second = InventoryBatch.create!(product: @product, batch_number: "RETURN-BATCH-2", expiry_date: 1.year.from_now,
      received_at: Time.current, original_quantity: 5, on_hand_quantity: 5, reserved_quantity: 0)
    Inventory::BatchAggregate.sync_product!(@product)
    sale = complete_sale(quantity: 4)
    item = sale.items.first
    assert_equal 2, item.batch_allocations.count
    original_sale = sale.attributes

    request = create_return(sale, item, 3)
    assert Returns::Review.new(return_request: request, actor: @admin, approve: true).call.success?
    result = Returns::Receive.new(return_request: request, actor: @inventory_manager,
      dispositions: { item: "restock", request.items.first.id => "restock" }, idempotency_key: "receive-multi").call
    assert result.success?, result.errors.join(", ")
    assert_equal 3, request.items.first.batch_allocations.sum(:quantity)
    assert_equal item.batch_allocations.map(&:inventory_batch_id).sort,
      request.items.first.batch_allocations.map(&:inventory_batch_id).sort
    movement_count = InventoryMovement.return_restock.count
    assert Returns::Receive.new(return_request: request, actor: @inventory_manager,
      dispositions: {}, idempotency_key: "receive-multi").call.success?
    assert_equal movement_count, InventoryMovement.return_restock.count
    assert_equal original_sale.except("updated_at"), sale.reload.attributes.except("updated_at")
    assert Inventory::BatchAggregate.consistent?(@product.reload)
  end

  test "cumulative requested quantity cannot exceed sold quantity" do
    sale = complete_sale(quantity: 2)
    item = sale.items.first
    assert create_return(sale, item, 1).persisted?
    assert create_return(sale, item, 1).persisted?
    denied = Returns::Create.new(source: sale, actor: @cashier,
      items: [ { source_item_id: item.id, quantity: 1, reason: "damaged", condition: "damaged" } ]).call
    assert_not denied.success?
    assert_equal 2, ReturnItem.where(source_item: item).sum(:requested_quantity)
  end

  test "cash refund lowers the refunding open session and is idempotent" do
    sale = complete_sale(quantity: 1)
    request = create_return(sale, sale.items.first, 1)
    Returns::Review.new(return_request: request, actor: @admin, approve: true).call
    Returns::Receive.new(return_request: request, actor: @inventory_manager,
      dispositions: { request.items.first.id => "restock" }, idempotency_key: "receive-refund").call
    refund_session = Pos::OpenSession.new(actor: @admin, opening_cash_cents: 20_000,
      identifier: "RETURN-REFUND-SHIFT").call.record
    before = refund_session.expected_cash
    result = Returns::Refund.new(return_request: request, actor: @admin,
      amount_cents: request.refundable_cents, payment_method: "cash", idempotency_key: "cash-refund").call
    assert result.success?, result.errors.join(", ")
    assert result.record.completed?
    assert_equal before - request.refundable_cents, refund_session.reload.expected_cash
    assert_equal result.record, Returns::Refund.new(return_request: request, actor: @admin,
      amount_cents: request.refundable_cents, payment_method: "cash", idempotency_key: "cash-refund").call.record
    assert_equal 1, Refund.where(idempotency_key: "cash-refund").count
  end

  test "expired original batch cannot be restocked" do
    sale = complete_sale(quantity: 1)
    allocation = sale.items.first.batch_allocations.first
    allocation.inventory_batch.update_columns(expiry_date: Date.yesterday)
    request = create_return(sale, sale.items.first, 1)
    Returns::Review.new(return_request: request, actor: @admin, approve: true).call
    result = Returns::Receive.new(return_request: request, actor: @inventory_manager,
      dispositions: { request.items.first.id => "restock" }, idempotency_key: "expired-restock").call
    assert_not result.success?
    assert request.reload.approved?
    assert_empty request.items.first.batch_allocations
  end

  test "refund to wallet and loyalty reversal are idempotent" do
    LoyaltyRule.create!(code: "RETURN-EARN", name: "كسب المرتجع", rule_type: :earning,
      points_awarded: 1, spend_threshold_cents: 100)
    customer = users(:customer)
    sale = complete_sale(quantity: 1, customer:)
    earned = customer.loyalty_account.ledger_entries.earn.find_by!(source: sale)
    request = create_return(sale, sale.items.first, 1)
    Returns::Review.new(return_request: request, actor: @admin, approve: true).call
    Returns::Receive.new(return_request: request, actor: @inventory_manager,
      dispositions: { request.items.first.id => "restock" }, idempotency_key: "receive-wallet-refund").call
    result = Returns::Refund.new(return_request: request, actor: @admin,
      amount_cents: request.refundable_cents, payment_method: "wallet", idempotency_key: "wallet-refund-return").call
    assert result.success?, result.errors.join(", ")
    assert_equal request.refundable_cents, customer.wallet_account.balance_cents
    assert_equal earned.points, customer.loyalty_account.ledger_entries.earn_reversal.where(source: sale).sum(:points)
    retry_result = Returns::Refund.new(return_request: request, actor: @admin,
      amount_cents: request.refundable_cents, payment_method: "wallet", idempotency_key: "wallet-refund-return").call
    assert_equal result.record, retry_result.record
    assert_equal 1, WalletLedgerEntry.refund.where(source: result.record).count
  end

  private

  def complete_sale(quantity:, customer: nil)
    sale = @session.pos_sales.create!(cashier: @cashier, customer:, number: "POS-RETURN-#{SecureRandom.hex(4)}")
    Pos::Cart.new(sale:, actor: @cashier).add(product: @product, quantity:)
    result = Pos::Complete.new(sale:, actor: @cashier, idempotency_key: "complete-#{sale.number}",
      payments: [ { payment_method: "cash", amount_cents: sale.total_cents, tendered_cents: sale.total_cents } ]).call
    assert result.success?, result.errors.join(", ")
    sale.reload
  end

  def create_return(sale, item, quantity)
    result = Returns::Create.new(source: sale, actor: @cashier,
      items: [ { source_item_id: item.id, quantity:, reason: "customer_changed_mind", condition: "unopened" } ]).call
    assert result.success?, result.errors.join(", ")
    result.record
  end
end
