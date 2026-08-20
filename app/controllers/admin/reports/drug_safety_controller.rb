module Admin::Reports
  class DrugSafetyController < BaseController
    before_action { authorize_capability!(:can_view_safety_reports?) }

    def index
      return export_report("drug_safety") if request.format.csv?
      @report = ::Reports::DrugSafetySummary.new(@date_range).call
    end
  end
end
