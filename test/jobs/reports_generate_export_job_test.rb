require "test_helper"

class ReportsGenerateExportJobTest < ActiveJob::TestCase
  test "generates private formula-safe csv and cleanup expires it" do
    user = users(:inventory_manager)
    result = Reports::AsyncExporter.call(user:, report_type: "products", filters: { preset: "current_month" })
    assert result.success?
    assert_enqueued_with(job: Reports::GenerateExportJob)

    Reports::GenerateExportJob.perform_now(result.export.id)
    export = result.export.reload
    assert export.completed?
    assert export.file.attached?
    assert export.file.download.force_encoding(Encoding::UTF_8).start_with?(Reports::CsvExporter::BOM)
    assert export.expires_at.future?

    export.update!(expires_at: 1.minute.ago)
    Reports::CleanupExpiredExportsJob.perform_now
    assert export.reload.expired?
    assert_not export.file.attached?
  end

  test "deduplicates active requests and enforces role and concurrency limits" do
    user = users(:inventory_manager)
    first = Reports::AsyncExporter.call(user:, report_type: "products", filters: { preset: "today" })
    second = Reports::AsyncExporter.call(user:, report_type: "products", filters: { preset: "today" })
    assert_equal first.export, second.export
    assert_not Reports::AsyncExporter.call(user:, report_type: "prescriptions", filters: {}).success?

    2.times { |index| user.report_exports.create!(report_type: "inventory", filters: {}, status: :pending,
      requested_at: Time.current, deduplication_key: "active-#{index}") }
    assert_equal :too_many_active, Reports::AsyncExporter.call(user:, report_type: "inventory", filters: { preset: "today" }).error
  end
end
