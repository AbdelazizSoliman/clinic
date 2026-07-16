require "test_helper"

class PromotionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "only admin accesses promotion administration" do
    sign_in users(:admin)
    get admin_promotions_path
    assert_response :success
    sign_out users(:admin)
    [ users(:customer), users(:inventory_manager), users(:order_manager) ].each do |user|
      sign_in user
      get admin_promotions_path
      assert_response :not_found
      sign_out user
    end
  end

  test "guest cart applies and removes normalized coupon without accepting ids" do
    promotion = Promotion.create!(name: "عرض", internal_name: "request", promotion_type: "cart",
      discount_type: "fixed_amount", discount_value: 500, starts_at: 1.hour.ago, ends_at: 1.day.from_now,
      active: true, created_by: users(:admin), updated_by: users(:admin))
    promotion.coupons.create!(code: "SAFE500")
    post cart_items_path, params: { cart_item: { product_id: products(:skin_product).id, quantity: 1 } }
    post coupon_application_path, params: { code: " safe500 ", promotion_id: -1, discount_cents: 999_999 }
    assert_redirected_to cart_path
    get cart_path
    assert_includes response.body, "SAFE500"
    delete coupon_application_path
    assert_redirected_to cart_path
  end

  test "invalid codes receive one generic response" do
    post cart_items_path, params: { cart_item: { product_id: products(:skin_product).id, quantity: 1 } }
    post coupon_application_path, params: { code: "NOT-A-CODE" }
    assert_redirected_to cart_path
    follow_redirect!
    assert_includes response.body, "الكود غير صالح أو غير متاح لهذه السلة"
  end
end
