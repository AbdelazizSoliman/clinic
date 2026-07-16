require "test_helper"

class DemoModeTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @previous_demo_mode = Rails.application.config.x.demo_mode
    @previous_protected_actions = Rails.application.config.x.demo_protected_actions
  end

  teardown do
    Rails.application.config.x.demo_mode = @previous_demo_mode
    Rails.application.config.x.demo_protected_actions = @previous_protected_actions
  end

  test "demo mode defaults to disabled" do
    assert_not DemoMode.enabled?
    assert_equal false, DemoMode.parse(nil)
    assert_equal false, DemoMode.parse("")
    assert_equal false, DemoMode.parse("false")
    assert_equal false, DemoMode.parse("0")
  end

  test "supported true values enable demo mode" do
    %w[1 true TRUE t yes Y on ON].each { |value| assert DemoMode.parse(value), value }
  end

  test "banner and navigation link appear only for authenticated users in demo mode" do
    sign_in users(:customer)

    Rails.application.config.x.demo_mode = false
    get root_path
    assert_response :success
    assert_select "[aria-label='تنبيه النسخة التجريبية']", count: 0
    assert_select "a[href='#{demo_path}']", count: 0

    Rails.application.config.x.demo_mode = true
    get root_path
    assert_response :success
    assert_select "[aria-label='تنبيه النسخة التجريبية']", text: /نسخة تجريبية/
    assert_select "a[href='#{demo_path}']", minimum: 1
  end

  test "demo information page requires authentication and enabled demo mode" do
    Rails.application.config.x.demo_mode = true
    get demo_path
    assert_redirected_to new_user_session_path

    sign_in users(:customer)
    get demo_path
    assert_response :success
    assert_select "html[lang='ar'][dir='rtl']"
    assert_select "h1", "عن النسخة التجريبية"

    Rails.application.config.x.demo_mode = false
    get demo_path
    assert_response :not_found
  end

  test "safety policy is inert normally and blocks configured actions only in demo mode" do
    Rails.application.config.x.demo_protected_actions = [ :critical_reset ]

    Rails.application.config.x.demo_mode = false
    assert DemoMode::SafetyPolicy.enforce!(:critical_reset)

    Rails.application.config.x.demo_mode = true
    assert DemoMode::SafetyPolicy.enforce!(:ordinary_update)
    assert_raises(DemoMode::SafetyPolicy::ProtectedActionError) do
      DemoMode::SafetyPolicy.enforce!(:critical_reset)
    end
  end
end
