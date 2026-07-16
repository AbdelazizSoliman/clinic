require "test_helper"

class Phase14SecurityTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "privileged user without two factor is redirected but customer is not" do
    admin = users(:admin)
    admin.update_columns(otp_secret: nil, otp_enabled_at: nil)
    post user_session_path, params: { user: { email: admin.email, password: "password123" } }
    get admin_users_path, headers: { "X-Enforce-2FA" => "1" }
    assert_redirected_to two_factor_enrollment_path

    delete destroy_user_session_path
    post user_session_path, params: { user: { email: users(:customer).email, password: "password123" } }
    get root_path
    assert_response :success
  end

  test "stale session version is rejected with a safe Arabic message" do
    user = users(:customer)
    sign_in user
    get account_path
    user.increment!(:session_version)
    get account_path
    assert_redirected_to new_user_session_path
    assert_equal I18n.t("security.session_stale"), flash[:alert]
  end

  test "health responses do not expose infrastructure details" do
    get rails_health_check_path
    assert_response :success
    get readiness_check_path
    assert_response :success
    assert_equal({ "status" => "ready" }, response.parsed_body)
  end

  test "responses include CSP and hardened headers" do
    get root_path
    assert_includes response.headers["Content-Security-Policy"], "default-src 'self'"
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    assert_equal "strict-origin-when-cross-origin", response.headers["Referrer-Policy"]
  end
end
