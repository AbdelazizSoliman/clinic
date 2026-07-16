module Admin
  module Reports
    class BaseController < ApplicationController
      before_action :authenticate_user!
      before_action :prepare_range
      layout "reports"

      private

      def prepare_range
        @date_range = ::Reports::DateRange.call(params.slice(:preset, :from, :to).permit!)
        return if @date_range.valid?
        redirect_to admin_reports_root_path(preset: "current_month"), alert: I18n.t("reports.errors.#{@date_range.error}")
      end

      def authorize_capability!(capability)
        head(:not_found) unless current_user.public_send(capability)
      end

      def export_report(type)
        return head(:not_found) unless current_user.can_export_reports?
        mapping = ::Reports::ExportRows.call(type, @date_range)
        export = ::Reports::CsvExporter.call(headers: mapping.headers, rows: mapping.rows)
        ReportExportEvent.create!(user: current_user, report_type: type, range_start: @date_range.start_at,
          range_end: @date_range.end_at, filters: safe_filters, row_count: export.row_count)
        send_data export.content, type: "text/csv; charset=utf-8",
          filename: "#{type}-#{@date_range.start_at.to_date}-#{(@date_range.end_at - 1.second).to_date}.csv", disposition: "attachment"
      rescue RangeError
        redirect_to request.path, alert: I18n.t("reports.errors.export_too_large")
      end

      def safe_filters
        params.slice(:preset, :from, :to, :status, :category_id, :brand_id, :zone_id).permit!.to_h
      end
    end
  end
end
