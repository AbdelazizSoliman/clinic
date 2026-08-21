require "test_helper"

class LoyaltyWalletTest < ActiveSupport::TestCase
  setup do
    @customer = users(:customer)
    @admin = users(:admin)
    @cashier = users(:order_manager)
    @product = products(:featured)
    @earning = LoyaltyRule.create!(code: "TEST-EARN", name: "نقطة لكل جنيه", rule_type: :earning,
      points_awarded: 1, spend_threshold_cents: 100, minimum_eligible_spend_cents: 100, expiration_days: 365)
    @redemption = LoyaltyRule.create!(code: "TEST-REDEEM", name: "مائة نقطة تساوي جنيهاً", rule_type: :redemption,
      redemption_points: 100, redemption_value_cents: 100, minimum_redemption_points: 100,
      maximum_redemption_points: 1_000)
  end

  test "ledger balances are derived and entries are immutable" do
    assert Wallet::Adjust.new(customer: @customer, actor: @admin, amount_cents: 5_000,
      direction: "credit", reason: "رصيد اختبار", idempotency_key: "wallet-adjust-1").call.success?
    wallet = @customer.wallet_account
    assert_equal 5_000, wallet.balance_cents
    entry = wallet.ledger_entries.sole
    assert_not entry.update(reason: "تعديل ممنوع")
    assert_not entry.destroy

    result = Loyalty::Adjust.new(customer: @customer, actor: @admin, points: 300,
      direction: "credit", reason: "تصحيح اختبار", idempotency_key: "loyalty-adjust-1").call
    assert result.success?
    assert_equal 300, @customer.loyalty_account.points_balance
    assert_not result.record.update(points: 400)
  end

  test "redemption consumes oldest expiring credit and retries without duplicate value" do
    account = @customer.ensure_loyalty_account!
    later = account.ledger_entries.create!(entry_type: :earn, points: 200, reason: "لاحق",
      occurred_at: 1.day.ago, expires_at: 20.days.from_now, idempotency_key: "earn-later")
    earlier = account.ledger_entries.create!(entry_type: :earn, points: 200, reason: "أقرب انتهاء",
      occurred_at: 2.days.ago, expires_at: 10.days.from_now, idempotency_key: "earn-earlier")
    source = build_sale(customer: @customer)
    service = Loyalty::Redeem.new(customer: @customer, source:, requested_points: 300,
      maximum_value_cents: 1_000, idempotency_key: "redeem-once")
    result = service.call
    assert result.success?, result.errors.join(", ")
    assert_equal 300, result.points
    assert_equal 100, account.reload.points_balance
    assert_equal 200, LoyaltyPointAllocation.find_by!(earn_entry: earlier).points
    assert_equal 100, LoyaltyPointAllocation.find_by!(earn_entry: later).points
    assert_equal result.record, service.call.record
    assert_equal 1, LoyaltyLedgerEntry.redeem.where(idempotency_key: "redeem-once").count
  end

  test "expiration posts an idempotent debit only for unconsumed points" do
    account = @customer.ensure_loyalty_account!
    earn = account.ledger_entries.create!(entry_type: :earn, points: 150, reason: "منتهي",
      occurred_at: 10.days.ago, expires_at: 1.day.ago, idempotency_key: "expired-earn")
    assert Loyalty::Expire.new(account:).call.success?
    assert_equal 0, account.points_balance
    assert_equal 150, earn.reload.consumption_allocations.sum(:points)
    assert Loyalty::Expire.new(account:).call.success?
    assert_equal 1, account.ledger_entries.expire.count
  end

  test "identified POS sale supports wallet plus cash and earns once without changing cash semantics" do
    Wallet::Adjust.new(customer: @customer, actor: @admin, amount_cents: 3_000,
      direction: "credit", reason: "رصيد POS", idempotency_key: "pos-wallet-credit").call
    Loyalty::Adjust.new(customer: @customer, actor: @admin, points: 200,
      direction: "credit", reason: "نقاط POS", idempotency_key: "pos-points-credit").call
    session = Pos::OpenSession.new(actor: @cashier, opening_cash_cents: 10_000, identifier: "LOYALTY-POS").call.record
    sale = session.pos_sales.create!(cashier: @cashier, customer: @customer, number: "POS-LOYALTY-WALLET")
    Pos::Cart.new(sale:, actor: @cashier).add(product: @product)
    original = sale.total_cents
    result = Pos::Complete.new(sale:, actor: @cashier, idempotency_key: "pos-loyalty-complete",
      loyalty_points: 100, payments: [
        { payment_method: "wallet", amount_cents: 1_000 },
        { payment_method: "cash", amount_cents: original - 100 - 1_000, tendered_cents: original - 100 - 1_000 }
      ]).call
    assert result.success?, result.errors.join(", ")
    assert_equal 1_000, sale.reload.wallet_paid_cents
    assert_equal 2_000, @customer.wallet_account.balance_cents
    cash = sale.payments.cash.sum(:amount_cents)
    assert_equal 10_000 + cash, session.expected_cash
    earned = @customer.loyalty_account.ledger_entries.earn.find_by!(source: sale)
    assert_equal (sale.total_cents - sale.wallet_paid_cents) / 100, earned.points
    assert Pos::Complete.new(sale:, actor: @cashier, idempotency_key: "pos-loyalty-complete", payments: []).call.success?
    assert_equal 1, @customer.loyalty_account.ledger_entries.earn.where(source: sale).count
  end

  test "anonymous POS cannot spend wallet and earns nothing" do
    session = Pos::OpenSession.new(actor: @cashier, opening_cash_cents: 0, identifier: "ANON-POS").call.record
    sale = session.pos_sales.create!(cashier: @cashier, number: "POS-ANON-WALLET")
    Pos::Cart.new(sale:, actor: @cashier).add(product: @product)
    result = Pos::Complete.new(sale:, actor: @cashier, idempotency_key: "anon-wallet",
      payments: [ { payment_method: "wallet", amount_cents: sale.total_cents } ]).call
    assert_not result.success?
    assert sale.reload.draft?
    assert_empty LoyaltyLedgerEntry.where(source: sale)
  end

  private

  def build_sale(customer:)
    session = Pos::OpenSession.new(actor: @cashier, opening_cash_cents: 0,
      identifier: "RULE-#{SecureRandom.hex(3)}").call.record
    session.pos_sales.create!(cashier: @cashier, customer:, number: "POS-RULE-#{SecureRandom.hex(3)}")
  end
end
