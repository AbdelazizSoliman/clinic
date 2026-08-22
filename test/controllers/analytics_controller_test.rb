require "test_helper"

class AnalyticsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "admin can view and export formula-safe tenant analytics" do
    sign_in users(:admin)
    get admin_analytics_path, params: { preset: "last_7_days" }
    assert_response :success
    assert_select "h1", /التحليلات/

    get admin_analytics_path(format: :csv), params: { preset: "last_7_days" }
    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_includes response.body, "gross_sales_cents"
  end

  test "branch limited staff receives only current branch analytics" do
    sign_in users(:order_manager)
    get admin_analytics_path
    assert_response :success
    assert_select "tbody tr", count: 1
  end

  test "customer cannot access analytics" do
    sign_in users(:customer)
    get admin_analytics_path
    assert_response :not_found
  end
end
