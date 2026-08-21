require "test_helper"

class LoyaltyWalletControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  test "customer sees only own benefit ledgers" do
    customer = users(:customer)
    other = users(:other_customer)
    Wallet::Credit.new(customer:, amount_cents: 500, entry_type: :credit, source: nil, actor: nil,
      reason: "رصيد العميل", idempotency_key: "own-wallet").call
    Wallet::Credit.new(customer: other, amount_cents: 900, entry_type: :credit, source: nil, actor: nil,
      reason: "رصيد آخر", idempotency_key: "other-wallet").call
    sign_in customer
    get benefits_path
    assert_response :success
    assert_includes response.body, "500"
    assert_not_includes response.body, "رصيد آخر"
  end

  test "anonymous and staff cannot access customer benefits" do
    get benefits_path
    assert_redirected_to new_user_session_path
    sign_in users(:order_manager)
    get benefits_path
    assert_response :not_found
  end

  test "only admin accesses adjustment interface" do
    sign_in users(:order_manager)
    get admin_loyalty_wallet_path
    assert_response :not_found
    sign_out users(:order_manager)
    sign_in users(:admin)
    get admin_loyalty_wallet_path
    assert_response :success
  end
end
