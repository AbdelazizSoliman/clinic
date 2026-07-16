module Admin::Reports
  class OrdersController < BaseController
    before_action { authorize_capability!(:can_view_business_reports?) }
    def index
      return export_report("orders") if request.format.csv?
      @report = ::Reports::OrdersSummary.new(@date_range).call
    end
  end
end
