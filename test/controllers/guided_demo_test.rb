require "test_helper"

class GuidedDemoTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @previous_demo_mode = Rails.application.config.x.demo_mode
    @previous_test_override = ENV["DEMO_SEED_TEST"]
    Rails.application.config.x.demo_mode = true
    ENV["DEMO_SEED_TEST"] = "true"
  end

  teardown do
    Rails.application.config.x.demo_mode = @previous_demo_mode
    ENV["DEMO_SEED_TEST"] = @previous_test_override
  end

  test "guided journeys resolve stable scenarios and retain role authorization" do
    DemoData::Seeder.call
    customer = User.find_by!(email: "customer@example.test")
    pharmacist = User.find_by!(email: "pharmacist@example.test")
    order_manager = User.find_by!(email: "staff@example.test")
    inventory_manager = User.find_by!(email: "inventory@example.test")
    admin = User.find_by!(email: "admin@example.test")

    sign_in customer
    get demo_path
    assert_response :success
    assert_select "html[lang='ar'][dir='rtl']"
    assert_select "article[data-demo-role='customer'][aria-current='step']", count: 1
    assert_select "article[data-demo-role='pharmacist'] a", count: 0
    assert_select "a[href='#{products_path}']"
    delivered = customer.orders.find_by!(number: "DEMO-DELIVERED-OLD")
    assert_select "a[href='#{order_path(delivered)}']"
    assert_sensitive_credentials_absent

    prescription = Prescription.joins(:order).find_by!(orders: { number: "DEMO-PRESCRIPTION-REVIEW" })
    protected_path = staff_prescription_path(prescription)
    get protected_path
    assert_response :not_found

    sign_out customer
    sign_in pharmacist
    get demo_path
    assert_select "article[data-demo-role='pharmacist'][aria-current='step']", count: 1
    assert_select "a[href='#{protected_path}']"
    get protected_path
    assert_response :success

    sign_out pharmacist
    sign_in order_manager
    preparing_order = Order.find_by!(number: "DEMO-PREPARING")
    get demo_path
    assert_select "article[data-demo-role='order_manager'][aria-current='step']", count: 1
    assert_select "a[href='#{staff_order_path(preparing_order)}']"
    get staff_order_path(preparing_order)
    assert_response :success

    sign_out order_manager
    sign_in inventory_manager
    get demo_path
    assert_select "article[data-demo-role='inventory_manager'][aria-current='step']", count: 1
    assert_select "a[href='#{admin_low_stock_inventory_path}']"
    get admin_low_stock_inventory_path
    assert_response :success

    sign_out inventory_manager
    sign_in admin
    promotion = Promotion.find_by!(internal_name: "demo:active-cart")
    get demo_path
    assert_select "article[data-demo-role='admin'][aria-current='step']", count: 1
    assert_select "a[href='#{admin_promotion_path(promotion)}']"
    assert_select "a[href='#{admin_security_path}']"
    get admin_security_path
    assert_response :success
  end

  test "demo navigation and login hint are absent when demo mode is disabled" do
    Rails.application.config.x.demo_mode = false
    sign_in users(:customer)

    get root_path
    assert_response :success
    assert_select "a[href='#{demo_path}']", count: 0
    assert_select "[aria-label='تلميح للنسخة التجريبية']", count: 0

    sign_out users(:customer)
    get new_user_session_path
    assert_response :success
    assert_select "[aria-label='تلميح للنسخة التجريبية']", count: 0
  end

  test "login explains temporary credentials without rendering them" do
    get new_user_session_path

    assert_response :success
    assert_select "[aria-label='تلميح للنسخة التجريبية']", text: /مشغّل العرض/
    assert_sensitive_credentials_absent
  end

  private

  def assert_sensitive_credentials_absent
    assert_not_includes response.body, "DemoOnly123!"
    assert_not_includes response.body, "JBSWY3DPEHPK3PXP"
    assert_not_includes response.body, "DEMO_TOTP_SECRET"
    assert_not_includes response.body, "DEMO_ACCOUNT_PASSWORD"
  end
end
