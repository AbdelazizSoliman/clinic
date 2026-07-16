require "test_helper"

class AuthenticationAndCartTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "authentication pages respond" do
    get new_user_session_url
    assert_response :success
    get new_user_registration_url
    assert_response :success
    get new_user_password_url
    assert_response :success
  end

  test "public registration cannot assign admin role" do
    post user_registration_url, params: { user: { email: "public@example.com", password: "password123", password_confirmation: "password123", first_name: "عميل", last_name: "جديد", mobile_number: "01088888888", role: "admin", active: false } }
    assert_response :redirect
    user = User.find_by!(email: "public@example.com")
    assert user.customer?
    assert user.active?
  end

  test "inactive user cannot sign in" do
    post user_session_url, params: { user: { email: users(:inactive).email, password: "password123" } }
    assert_redirected_to new_user_session_url
    follow_redirect!
    assert_select "h1", "تسجيل الدخول"
  end

  test "account requires authentication and profile cannot change role" do
    get account_url
    assert_redirected_to new_user_session_url
    sign_in users(:customer)
    patch account_url, params: { user: { first_name: "محدث", role: "admin", active: false } }
    assert_redirected_to account_url
    assert_equal "محدث", users(:customer).reload.first_name
    assert users(:customer).customer?
    assert users(:customer).active?
  end

  test "guest cart mutations persist in the session and trust database price" do
    post cart_items_url, params: { cart_item: { product_id: products(:featured).id, quantity: 2, price: 1 } }
    assert_response :see_other
    get cart_url
    assert_response :success
    assert_select "#cart_page_state", /#{products(:featured).name}/
    assert_select "#cart_page_state", /#{products(:featured).price.to_i}/
  end

  test "rejects unavailable invalid and malformed products" do
    post cart_items_url, params: { cart_item: { product_id: products(:inactive).id, quantity: 1 } }
    assert_response :see_other
    post cart_items_url, params: { cart_item: { product_id: 999_999, quantity: 1 } }
    assert_response :see_other
    post cart_items_url, params: { cart_item: { product_id: products(:featured).id, quantity: "bad" } }
    assert_response :see_other
  end

  test "cannot mutate another users cart item" do
    sign_in users(:customer)
    patch cart_item_url(cart_items(:other_item)), params: { cart_item: { quantity: 5 } }
    assert_response :not_found
    assert_equal 1, cart_items(:other_item).reload.quantity
  end

  test "Turbo cart mutation updates server fragments" do
    post cart_items_url, params: { cart_item: { product_id: products(:skin_product).id, quantity: 1 } }, as: :turbo_stream
    assert_response :success
    assert_select "turbo-stream[action='replace'][target='cart_badge']"
    assert_select "turbo-stream[action='replace'][target='cart_drawer_content']"
  end

  test "checkout renders trusted server cart and prescription notice" do
    sign_in users(:customer)
    products(:featured).update!(requires_prescription: true)
    get checkout_url
    assert_response :success
    assert_select "form[data-checkout-target='form']"
    assert_select "h2", /إرسال الروشتة/
  end

  test "guest cart merges on sign in and persists across sign out" do
    post cart_items_url, params: { cart_item: { product_id: products(:skin_product).id, quantity: 3 } }
    post user_session_url, params: { user: { email: users(:customer).email, password: "password123" } }
    assert_redirected_to root_url
    assert_equal 3, carts(:customer_cart).items.find_by(product: products(:skin_product)).quantity

    delete destroy_user_session_url
    post user_session_url, params: { user: { email: users(:customer).email, password: "password123" } }
    get cart_url
    assert_select "#cart_page_state", /#{products(:skin_product).name}/
  end

  test "browser cart import is server validated and idempotent" do
    payload = { items: [ { productId: products(:skin_product).id, quantity: 99 }, { productId: 999_999, quantity: 5 } ] }
    post import_browser_cart_url, params: payload, as: :json
    assert_response :success
    assert_equal "imported", response.parsed_body["status"]
    assert_equal 5, response.parsed_body["count"]

    post import_browser_cart_url, params: payload, as: :json
    assert_equal "already_imported", response.parsed_body["status"]
  end

  test "updates removes and clears only the current cart" do
    sign_in users(:customer)
    patch cart_item_url(cart_items(:customer_item)), params: { cart_item: { quantity: 4 } }
    assert_equal 4, cart_items(:customer_item).reload.quantity
    delete cart_item_url(cart_items(:customer_item))
    assert_nil CartItem.find_by(id: cart_items(:customer_item).id)
    post clear_cart_url
    assert_empty carts(:customer_cart).items.reload
  end
end
