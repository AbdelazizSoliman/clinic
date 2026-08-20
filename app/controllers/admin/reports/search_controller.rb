module Admin::Reports
  class SearchController < BaseController
    before_action { authorize_capability!(:can_view_search_reports?) }

    def index
      return export_report("search") if request.format.csv?
      @report = ::Reports::SearchSummary.new(@date_range).call
    end
  end
end
