require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "admin views dashboard and exports audited UTF-8 CSV" do
    sign_in users(:admin)
    get admin_reports_root_path
    assert_response :success
    assert_includes response.body, "لوحة التقارير التشغيلية"
    get admin_reports_customers_path
    assert_response :success

    assert_difference("ReportExportEvent.count") do
      get admin_reports_sales_path(format: :csv, preset: "current_month")
    end
    assert_response :success
    assert_equal "text/csv", response.media_type
    assert response.body.start_with?(Reports::CsvExporter::BOM)
    assert_match(/sales-\d{4}-\d{2}-\d{2}-\d{4}-\d{2}-\d{2}\.csv/, response.headers["Content-Disposition"])
  end

  test "report access follows the role capability matrix" do
    assertions = {
      inventory_manager: [ admin_reports_inventory_index_path, admin_reports_products_path ],
      pharmacist: [ admin_reports_prescriptions_path ],
      order_manager: [ admin_reports_sales_path, admin_reports_orders_path, admin_reports_fulfilments_path ]
    }

    assertions.each do |role, paths|
      sign_in users(role)
      paths.each do |path|
        get path
        assert_response :success, "expected #{role} to access #{path}"
      end
      sign_out users(role)
    end
  end

  test "roles cannot cross report privacy boundaries" do
    {
      customer: admin_reports_root_path,
      pharmacist: admin_reports_sales_path,
      order_manager: admin_reports_prescriptions_path,
      inventory_manager: admin_reports_customers_path
    }.each do |role, path|
      sign_in users(role)
      get path
      assert_response :not_found
      sign_out users(role)
    end
  end

  test "invalid custom date redirects without running report queries" do
    sign_in users(:admin)
    get admin_reports_sales_path, params: { preset: "custom", from: "not-a-date", to: "2026-07-16" }

    assert_redirected_to admin_reports_root_path(preset: "current_month")
  end
end
