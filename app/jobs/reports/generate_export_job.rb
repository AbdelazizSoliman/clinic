module Reports
  class GenerateExportJob < ApplicationJob
    queue_as :exports
    retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 3

    def perform(export_id)
      export = ReportExport.find(export_id)
      return if export.completed? || export.expired?
      unless AsyncExporter.authorized?(export.user, export.report_type)
        export.update!(status: :failed, failed_at: Time.current, error_class: "AuthorizationChanged")
        return
      end
      export.update!(status: :processing, started_at: Time.current, error_class: nil)
      range = DateRange.call(export.filters)
      raise ArgumentError, "InvalidExportRange" unless range.valid?
      mapping = ExportRows.call(export.report_type, range)
      csv = CsvExporter.call(headers: mapping.headers, rows: mapping.rows)
      export.file.attach(io: StringIO.new(csv.content), filename: safe_filename(export, range), content_type: "text/csv")
      export.update!(status: :completed, row_count: csv.row_count, completed_at: Time.current,
        expires_at: ReportExport::RETENTION.from_now)
      notify(export, "report_export_completed", "اكتمل تصدير التقرير", "أصبح ملف التقرير جاهزًا للتنزيل.")
    rescue => error
      export&.update!(status: :failed, failed_at: Time.current, error_class: error.class.name)
      notify(export, "report_export_failed", "تعذر تصدير التقرير", "تعذر إنشاء ملف التقرير. حاول مرة أخرى لاحقًا.") if export
      Errors::Reporter.capture(error, context: { job_class: self.class.name })
    end

    private

    def safe_filename(export, range)
      "#{export.report_type}-#{range.start_at.to_date}-#{(range.end_at - 1.second).to_date}.csv"
    end

    def notify(export, kind, title, body)
      Notifications::Create.call(user: export.user, notifiable: export, kind:, title:, body:,
        key: "#{kind}:#{export.id}")
    end
  end
end
