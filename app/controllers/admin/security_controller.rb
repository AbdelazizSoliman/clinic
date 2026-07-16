module Admin
  class SecurityController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_admin!
    layout "admin"

    def show
      @missing_two_factor = User.where.not(role: User.roles[:customer]).where(active: true, otp_enabled_at: nil).order(:id).limit(25)
      @locked_accounts = User.where.not(role: User.roles[:customer]).where.not(locked_at: nil).order(locked_at: :desc).limit(25)
      @security_events = SecurityEvent.includes(:user, :actor).order(created_at: :desc).limit(50)
      @email_failures = TransactionalEmailDelivery.failed.includes(:user).order(failed_at: :desc).limit(25)
      @heartbeats = JobHeartbeat.order(:job_name).limit(50)
      @scan_issues = Prescription.where(scan_status: %i[pending failed infected]).order(created_at: :desc).limit(25)
      @export_issues = ReportExport.where(status: %i[pending processing failed]).order(created_at: :desc).limit(25)
      @integrity_findings = Operations::IntegrityCheck.new.call
      @configuration_warnings = configuration_warnings
    end

    private

    def authorize_admin!
      head(:not_found) unless current_user.admin?
    end

    def configuration_warnings
      warnings = []
      warnings << "ماسح البرمجيات الخبيثة الحقيقي غير مهيأ" if ENV.fetch("MALWARE_SCANNER_ADAPTER", "unconfigured") == "unconfigured"
      warnings << "موفر تتبع الأخطاء الخارجي غير مهيأ" if ENV.fetch("ERROR_REPORTER_ADAPTER", "logging") == "logging"
      warnings
    end
  end
end
