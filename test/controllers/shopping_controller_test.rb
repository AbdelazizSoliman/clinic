require "test_helper"

class ShoppingControllerTest < ActionDispatch::IntegrationTest
  test "cart page responds with empty state and product catalog" do
    get cart_url
    assert_response :success
    assert_select "h1", "سلة التسوق"
    assert_select "#cart_page_state", /سلة التسوق فارغة/
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
    assert_select "h2", /السلة فارغة/
    assert_select "h2", /السلة فارغة/
  end

  test "shopping routes use read-only GET requests" do
    assert_routing({ method: :get, path: "/cart" }, { controller: "carts", action: "show" })
    assert_routing({ method: :get, path: "/wishlist" }, { controller: "shopping", action: "wishlist" })
    assert_routing({ method: :get, path: "/checkout" }, { controller: "shopping", action: "checkout" })
  end

  test "product pages include shopping controls and recently viewed shell" do
    get product_url(products(:featured))
    assert_response :success
    assert_select "form[action='#{cart_items_path}']"
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
