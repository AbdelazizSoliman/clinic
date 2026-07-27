module Admin::Reports
  class PurchasingController < BaseController
    before_action { authorize_capability!(:can_view_purchasing_reports?) }
    def index
      return export_report("purchasing") if request.format.csv?
      @report = ::Reports::PurchasingSummary.new(@date_range).call
    end
  end
end
