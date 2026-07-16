class ReportExportsController < ApplicationController
  before_action :authenticate_user!

  def index
    @report_exports = current_user.report_exports.recent_first.limit(50)
  end

  def create
    result = Reports::AsyncExporter.call(user: current_user, report_type: params[:report_type], filters: params[:filters] || {})
    if result.success?
      redirect_to report_exports_path, notice: t("reports.exports.queued"), status: :see_other
    else
      redirect_back fallback_location: admin_reports_root_path, alert: t("reports.exports.#{result.error}"), status: :see_other
    end
  end

  def download
    export = ReportExport.find(params[:id])
    return head(:not_found) unless export.downloadable_by?(current_user)
    send_data export.file.download, filename: export.file.filename.to_s,
      type: "text/csv; charset=utf-8", disposition: "attachment"
  end
end
