module Admin::Reports
  class PrescriptionsController < BaseController
    before_action { authorize_capability!(:can_view_prescription_reports?) }
    def index
      return export_report("prescriptions") if request.format.csv?
      @report = ::Reports::PrescriptionPerformance.new(@date_range).call
    end
  end
end
