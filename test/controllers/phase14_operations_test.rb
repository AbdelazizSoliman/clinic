require "test_helper"

class Phase14OperationsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "security dashboard and email retry are admin only" do
    sign_in users(:customer)
    get admin_security_path
    assert_response :not_found
    sign_out users(:customer)

    sign_in users(:admin)
    get admin_security_path
    assert_response :success
    assert_includes response.body, "الأمن وسلامة التشغيل"

    delivery = TransactionalEmailDelivery.create!(user: users(:customer), mailer: "NotificationMailer",
      action: "customer_update", status: :failed, queued_at: Time.current, failed_at: Time.current,
      deduplication_key: "retry:controller")
    assert_difference("SecurityEvent.count") { patch retry_admin_email_delivery_path(delivery) }
    assert_redirected_to admin_email_deliveries_path
  end

  test "exports are owned and downloaded only through application authorization" do
    owner = users(:inventory_manager)
    export = owner.report_exports.create!(report_type: "products", filters: {}, status: :completed,
      requested_at: Time.current, completed_at: Time.current, expires_at: 1.day.from_now,
      deduplication_key: "download:1")
    export.file.attach(io: StringIO.new("\uFEFFsafe"), filename: "products.csv", content_type: "text/csv")

    sign_in users(:customer)
    get download_report_export_path(export)
    assert_response :not_found
    sign_out users(:customer)
    sign_in owner
    get download_report_export_path(export)
    assert_response :success
    assert_equal "text/csv", response.media_type
  end

  test "static Arabic error fallbacks are branded and RTL" do
    %w[404 422 429 500 503].each do |status|
      body = Rails.public_path.join("#{status}.html").read
      assert_includes body, "lang=\"ar\""
      assert_includes body, "dir=\"rtl\""
      assert_not_includes body, "stack trace"
    end
  end

  test "rate limiting returns Arabic HTML and Retry-After while health remains available" do
    previous = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    11.times { post user_session_path, params: { user: { email: "nobody@example.com", password: "invalid-password" } } }
    assert_response :too_many_requests
    assert response.headers["Retry-After"].present?
    assert_includes response.body, "محاولات كثيرة"
    get readiness_check_path
    assert_response :success
  ensure
    Rack::Attack.cache.store = previous
  end
end
