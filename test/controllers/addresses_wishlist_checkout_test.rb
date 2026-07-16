require "test_helper"

class AddressesWishlistCheckoutTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  setup { @user = users(:customer) }

  test "addresses require authentication" do
    get account_addresses_path
    assert_redirected_to new_user_session_path
  end

  test "customer manages own addresses with protected ownership" do
    sign_in @user
    get account_addresses_path
    assert_response :success
    assert_select "h1", "عناوين التوصيل"

    assert_difference "@user.addresses.count" do
      post account_addresses_path, params: { address: { label: "العائلة", recipient_name: "أحمد محمد", mobile_number: "01012345678", governorate: "القاهرة", city: "الشروق", street: "طريق السويس", building_number: "4", default: "1", user_id: users(:other_customer).id } }
    end
    assert_equal @user.id, Address.order(:created_at).last.user_id

    patch set_default_account_address_path(addresses(:other_home))
    assert_response :not_found
    patch deactivate_account_address_path(addresses(:office))
    assert_redirected_to account_addresses_path
    assert_not addresses(:office).reload.active?
  end

  test "address invalid create renders errors and turbo frame request works" do
    sign_in @user
    post account_addresses_path, params: { address: { label: "" } }, headers: { "Turbo-Frame" => "checkout_address_form" }
    assert_response :unprocessable_entity
  end

  test "guest wishlist page remains browser based" do
    get wishlist_path
    assert_response :success
    assert_select "[data-controller='wishlist-page']"
  end

  test "authenticated wishlist add repeat remove clear and ownership" do
    sign_in @user
    assert_difference "@user.wishlist_items.count", 1 do
      post wishlist_items_path, params: { wishlist_item: { product_id: products(:skin_product).id, user_id: users(:other_customer).id } }
    end
    assert_no_difference "@user.wishlist_items.count" do
      post wishlist_items_path, params: { wishlist_item: { product_id: products(:skin_product).id } }
    end
    delete wishlist_item_path(wishlist_items(:other_skin))
    assert_response :not_found
    delete clear_wishlist_path
    assert_redirected_to wishlist_path
    assert_empty @user.wishlist_items.reload
  end

  test "wishlist turbo response updates synchronized controls" do
    sign_in @user
    post wishlist_items_path, params: { wishlist_item: { product_id: products(:skin_product).id } }, as: :turbo_stream
    assert_response :success
    assert_includes response.body, "wishlist_badge"
    assert_includes response.body, "data-wishlist-control-product-id"
  end

  test "wishlist import validates active ids and requires authentication" do
    post import_browser_wishlist_path, params: { product_ids: [ products(:skin_product).id ] }, as: :json
    assert_response :unauthorized
    sign_in @user
    post import_browser_wishlist_path, params: { product_ids: [ products(:skin_product).id, products(:inactive).id, 999_999 ] }, as: :json
    assert_response :success
    assert @user.wishlist_items.exists?(product: products(:skin_product))
  end

  test "guest checkout redirects safely then returns after sign in" do
    get checkout_path, params: { return_to: "https://evil.example" }
    assert_redirected_to new_user_session_path
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
    assert_redirected_to checkout_path
  end

  test "checkout validates owned active address and does not mutate cart" do
    sign_in @user
    status = carts(:customer_cart).status
    get checkout_path, params: { address_id: addresses(:other_home).id }
    assert_response :success
    assert_select "input[name='address_id'][value='#{addresses(:home).id}'][checked]"
    assert_equal status, carts(:customer_cart).reload.status
  end

  test "checkout shows no address, unsupported area, stock and prescription preparation" do
    user = users(:other_customer)
    sign_in user
    get checkout_path
    assert_response :success
    assert_includes response.body, "خارج نطاق التوصيل التجريبي"
    assert_includes response.body, "لن يتم إنشاء طلب"
  end
end
