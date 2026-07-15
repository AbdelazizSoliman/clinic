require "test_helper"

class ShoppingControllerTest < ActionDispatch::IntegrationTest
  test "cart page responds with empty state and product catalog" do
    get cart_url
    assert_response :success
    assert_select "h1", "سلة التسوق"
    assert_select "[data-cart-page-target='empty']", /سلة التسوق فارغة/
    assert_select "script#product-catalog", /#{products(:featured).name}/
  end

  test "wishlist page responds with reusable product cards" do
    get wishlist_url
    assert_response :success
    assert_select "h1", "قائمة المفضلة"
    assert_select "[data-wishlist-page-target='empty']", /لم تحفظ منتجات بعد/
    assert_select "[data-wishlist-page-target='item']", minimum: 2
  end

  test "checkout page responds with mock form and prescription notice" do
    get checkout_url
    assert_response :success
    assert_select "h1", "إتمام بيانات الطلب"
    assert_select "form[data-checkout-target='form']"
    assert_select "[data-checkout-target='prescription']", /مراجعة الروشتة/
    assert_select "button[type='submit']", /محاكاة إتمام الطلب/
  end

  test "shopping routes use read-only GET requests" do
    assert_routing({ method: :get, path: "/cart" }, { controller: "shopping", action: "cart" })
    assert_routing({ method: :get, path: "/wishlist" }, { controller: "shopping", action: "wishlist" })
    assert_routing({ method: :get, path: "/checkout" }, { controller: "shopping", action: "checkout" })
  end

  test "product pages include shopping controls and recently viewed shell" do
    get product_url(products(:featured))
    assert_response :success
    assert_select "[data-controller~='product-purchase']"
    assert_select "[data-controller='recently-viewed']"
    assert_select "[data-recently-viewed-target='section']", /شوهدت مؤخرًا/
  end

  test "storefront shell includes cart drawer, wishlist count, and toast region" do
    get root_url
    assert_response :success
    assert_select "#cart-drawer[role='dialog']"
    assert_select "[data-shopping-count-type-value='wishlist']"
    assert_select "[data-controller='toast'][aria-live='polite']"
  end
end
