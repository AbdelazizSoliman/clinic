require "test_helper"

class BatchInventoryControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "inventory roles access batches while other roles are denied" do
    [ users(:customer), users(:pharmacist), users(:order_manager) ].each do |user|
      sign_in user
      get admin_inventory_batches_path
      assert_response :not_found
      sign_out user
    end
    [ users(:inventory_manager), users(:admin) ].each do |user|
      sign_in user
      get admin_inventory_batches_path
      assert_response :success
      get admin_reports_batches_path
      assert_response :success
      sign_out user
    end
  end
end
