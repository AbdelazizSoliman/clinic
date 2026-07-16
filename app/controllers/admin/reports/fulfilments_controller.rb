module Admin::Reports
  class FulfilmentsController < BaseController
    before_action { authorize_capability!(:can_view_fulfilment_reports?) }
    def index
      return export_report("fulfilments") if request.format.csv?
      @report = ::Reports::FulfilmentPerformance.new(@date_range).call
    end
  end
end
