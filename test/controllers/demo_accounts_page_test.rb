require "test_helper"

class DemoAccountsPageTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @previous_demo_mode = Rails.application.config.x.demo_mode
    @previous_test_override = ENV["DEMO_SEED_TEST"]
    Rails.application.config.x.demo_mode = true
    ENV["DEMO_SEED_TEST"] = "true"
    sign_in users(:customer)
  end

  teardown do
    Rails.application.config.x.demo_mode = @previous_demo_mode
    ENV["DEMO_SEED_TEST"] = @previous_test_override
  end

  test "demo page lists roles and emails but no passwords or TOTP secrets" do
    get demo_path

    assert_response :success
    assert_select "h2", "حسابات العرض"
    assert_includes response.body, "admin@example.test"
    assert_includes response.body, "pharmacist@example.test"
    assert_includes response.body, "staff@example.test"
    assert_includes response.body, "inventory@example.test"
    assert_includes response.body, "customer@example.test"
    assert_not_includes response.body, "DemoOnly123!"
    assert_not_includes response.body, "JBSWY3DPEHPK3PXP"
  end

  test "protected demo accounts cannot start password recovery in demo mode" do
    DemoData::Seeder.call
    sign_out users(:customer)
    admin = User.find_by!(email: "admin@example.test")

    assert_no_changes -> { admin.reload.reset_password_token } do
      assert_no_enqueued_jobs do
        post user_password_path, params: { user: { email: admin.email } }
      end
    end
    assert_redirected_to new_user_session_path

    Rails.application.config.x.demo_mode = false
    assert_changes -> { admin.reload.reset_password_token } do
      post user_password_path, params: { user: { email: admin.email } }
    end
    assert admin.reload.reset_password_token.present?
  end
end
