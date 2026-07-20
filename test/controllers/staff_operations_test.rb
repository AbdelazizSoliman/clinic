require "test_helper"

class StaffOperationsRequestTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "customer denied while each staff role sees authorized queues" do
    sign_in users(:customer)
    get staff_root_path
    assert_response :not_found
    sign_out users(:customer)

    sign_in users(:pharmacist)
    get staff_root_path
    assert_response :success
    get staff_prescriptions_path
    assert_response :success
    get staff_prescriptions_path(q: "DEMO-PRESCRIPTION-REVIEW")
    assert_response :success
    assert_no_match(/Translation missing/, response.body)
    sign_out users(:pharmacist)

    sign_in users(:order_manager)
    get staff_orders_path(status: "submitted", sort: "bad")
    assert_response :success
    get staff_prescriptions_path
    assert_response :not_found
    sign_out users(:order_manager)

    sign_in users(:admin)
    get staff_root_path
    assert_response :success
  end

  test "public registration still cannot create staff" do
    post user_registration_path, params: { user: { email: "role7@example.com", password: "password123", password_confirmation: "password123", first_name: "عميل", last_name: "جديد", mobile_number: "01088888881", role: "pharmacist" } }
    assert User.find_by!(email: "role7@example.com").customer?
  end
end
