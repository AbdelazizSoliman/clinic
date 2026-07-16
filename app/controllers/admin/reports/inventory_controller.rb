module Admin::Reports
  class InventoryController < BaseController
    before_action { authorize_capability!(:can_view_inventory_reports?) }
    def index
      return export_report("inventory") if request.format.csv?
      @report = ::Reports::InventorySummary.new(@date_range).call
    end
  end
end
