require "test_helper"

class OrdersFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:customer)
    sign_in @user
    @cart = carts(:customer_cart)
    @cart.update!(checkout_submission_token: SecureRandom.urlsafe_base64(32))
  end

  test "authenticated checkout creates trusted order and redirects to public number" do
    assert_difference "Order.count", 1 do
      post orders_path, params: order_payload.merge(order: order_payload[:order].merge(total_cents: 1, status: "delivered", user_id: users(:other_customer).id, cart_id: carts(:other_cart).id))
    end
    order = Order.order(:created_at).last
    assert_redirected_to order_path(order)
    assert_equal @user, order.user
    assert_equal @cart, order.cart
    assert_equal products(:featured).price * 100 * 2, order.total_cents
    assert order.submitted?
    assert @cart.reload.completed?
    assert_equal 2, order.inventory_reservations.sum(:quantity)
  end

  test "double submission returns same order and completed cart gets replaced on new shopping" do
    post orders_path, params: order_payload
    order = Order.order(:created_at).last
    post orders_path, params: order_payload
    assert_redirected_to order_path(order)
    assert_equal 1, Order.where(cart: @cart).count

    post cart_items_path, params: { cart_item: { product_id: products(:skin_product).id, quantity: 1 } }
    new_cart = @user.carts.active.first
    assert new_cart
    assert_not_equal @cart, new_cart
    assert_equal 1, new_cart.items.count
  end

  test "ownership scopes order index show and prescription download" do
    post orders_path, params: order_payload
    order = Order.order(:created_at).last
    get orders_path
    assert_response :success
    assert_select "a", text: order.number
    sign_out @user
    sign_in users(:other_customer)
    get order_path(order)
    assert_response :not_found
    get order_prescription_file_path(order, 999)
    assert_response :not_found
  end

  test "tampered address and invalid submission do not create order or complete cart" do
    assert_no_difference "Order.count" do
      post orders_path, params: order_payload.merge(order: order_payload[:order].merge(address_id: addresses(:other_home).id))
    end
    assert_response :unprocessable_entity
    assert @cart.reload.active?
  end

  test "prescription upload is required and secure file downloads for owner" do
    products(:featured).update!(requires_prescription: true)
    assert_no_difference "Order.count" do
      post orders_path, params: order_payload
    end
    assert_response :unprocessable_entity
    file = fixture_file_upload("prescription.pdf", "application/pdf")
    post orders_path, params: order_payload.merge(order: order_payload[:order].merge(prescription_files: [ file ]))
    order = Order.order(:created_at).last
    assert order.pending_prescription?
    attachment = order.prescription.images.first
    get order_prescription_file_path(order, attachment.id)
    assert_response :success
    assert_equal "attachment", response.headers["Content-Disposition"].split(";").first
  end

  private

  def order_payload
    { order: { address_id: addresses(:home).id, delivery_method: "standard", payment_method: "cash_on_delivery", submission_token: @cart.checkout_submission_token, delivery_notes: "الاتصال قبل الوصول" } }
  end
end
