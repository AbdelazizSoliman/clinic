module Admin::Reports
  class CustomersController < BaseController
    before_action { head(:not_found) unless current_user.admin? }
    def index
      return export_report("customers") if request.format.csv?
      @report = ::Reports::CustomerSummary.new(@date_range).call
    end
  end
end
