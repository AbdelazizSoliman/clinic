require "test_helper"

class AdminCatalogTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "inventory manager and admin access while unrelated roles are denied" do
    [ users(:customer), users(:pharmacist), users(:order_manager) ].each do |user|
      sign_in user
      get admin_root_path
      assert_response :not_found
      sign_out user
    end
    sign_in users(:inventory_manager)
    get admin_root_path
    assert_response :success
    get admin_products_path(q: "skin", sort: "invalid")
    assert_response :success
  end

  test "product strong parameters do not overwrite price or stock" do
    sign_in users(:inventory_manager)
    product = products(:skin_product)
    patch admin_product_path(product), params: { product: { name: "اسم إداري", slug: product.slug,
      category_id: product.category_id, brand_id: product.brand_id, price: 1, stock_quantity: 999,
      low_stock_threshold: 4, maximum_order_quantity: 8, lock_version: product.lock_version } }
    assert_redirected_to admin_product_path(product)
    product.reload
    assert_equal "اسم إداري", product.name
    assert_not_equal 1, product.price
    assert_not_equal 999, product.stock_quantity
  end

  test "pricing and stock endpoints use audited services" do
    sign_in users(:inventory_manager)
    product = products(:skin_product)
    patch update_pricing_admin_product_path(product), params: { price: 260, compare_at_price: 300, cost_price: 200,
      reason: "تحديث إداري", lock_version: product.lock_version }
    assert_redirected_to admin_product_path(product)
    assert product.price_changes.exists?
    post admin_inventory_adjustments_path, params: { product_id: product.id, movement_type: "manual_increase", quantity: 2,
      reason: "جرد", lock_version: product.reload.lock_version }
    assert_redirected_to admin_product_path(product)
    assert product.inventory_movements.manual_increase.exists?
  end
end
