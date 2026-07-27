require "test_helper"

class PosControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "POS authorization follows role mapping" do
    %i[admin pharmacist order_manager].each do |role|
      sign_in users(role)
      get pos_root_path
      assert_response :success
      sign_out users(role)
    end
    %i[customer inventory_manager].each do |role|
      sign_in users(role)
      get pos_root_path
      assert_response :not_found
      sign_out users(role)
    end
  end

  test "cashier opens session uses barcode and sees printable receipt" do
    product = products(:featured)
    product.update!(barcode: "6229999999999")
    sign_in users(:order_manager)
    post pos_sessions_path, params: { opening_cash_cents: 5000 }
    assert_redirected_to pos_root_path
    get new_pos_sale_path
    assert_response :success
    post pos_sales_path
    sale = PosSale.last
    post pos_sale_items_path(sale), params: { barcode: product.barcode }
    assert_equal 1, sale.items.reload.count
    assert_no_difference("PosSaleItem.count") do
      post pos_sale_items_path(sale), params: { barcode: "NOT-FOUND" }
    end
    post complete_pos_sale_path(sale), params: { idempotency_key: "controller-pos",
      payment_method: "cash", amount_cents: sale.reload.total_cents, tendered_cents: sale.total_cents }
    assert sale.reload.completed?
    get pos_sale_path(sale)
    assert_response :success
    assert_includes response.body, "طباعة الإيصال"
    assert_not_includes response.body, "prescription_approval_reason"
  end

  test "exact barcode search and not found feedback are scanner friendly" do
    product = products(:featured)
    product.update!(barcode: "6221111111111", sku: "SCAN-SKU")
    sign_in users(:pharmacist)
    get pos_products_path, params: { q: product.barcode }
    assert_response :success
    assert_includes response.body, product.name
    get pos_products_path, params: { q: "does-not-exist" }
    assert_response :success
    assert_includes response.body, "لا يوجد منتج مطابق"
  end
end
