module Admin::Reports
  class ProductsController < BaseController
    before_action { head(:not_found) unless current_user.can_view_business_reports? || current_user.can_view_inventory_reports? }
    def index
      return export_report("products") if request.format.csv?
      @pagy, @rows = pagy(::Reports::ProductPerformance.new(@date_range).call, limit: 25)
    end
  end
end
