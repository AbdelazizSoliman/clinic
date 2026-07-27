module Admin::Reports
  class BatchesController < BaseController
    before_action { authorize_capability!(:can_view_inventory_reports?) }

    def index
      return export_report("batches") if request.format.csv?
      @report = ::Reports::BatchInventorySummary.new(@date_range).call
    end
  end
end
