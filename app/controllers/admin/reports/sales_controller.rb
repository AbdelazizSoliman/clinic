module Admin::Reports
  class SalesController < BaseController
    before_action { authorize_capability!(:can_view_business_reports?) }
    def index
      return export_report("sales") if request.format.csv?
      @report = ::Reports::SalesSummary.new(@date_range).call
    end
  end
end
