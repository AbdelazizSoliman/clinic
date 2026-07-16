require "test_helper"

class DeliveryOperationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "order manager can browse delivery zones and fulfilment queue" do
    sign_in users(:order_manager)
    get staff_delivery_zones_path
    assert_response :success
    assert_select "h1", text: "مناطق التوصيل"
    get staff_fulfilments_path
    assert_response :success
  end

  test "unrelated roles cannot access delivery operations" do
    [ users(:customer), users(:pharmacist), users(:inventory_manager) ].each do |user|
      sign_in user
      get staff_delivery_zones_path
      assert_response :not_found
      sign_out user
    end
  end

  test "checkout renders database delivery methods and slot selector" do
    sign_in users(:customer)
    get checkout_path
    assert_response :success
    assert_select "input[name='order[delivery_method]'][value='standard']"
    assert_select "select[name='order[delivery_slot_id]']"
    assert_includes response.body, delivery_zones(:cairo).name
  end
end
