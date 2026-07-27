module Admin
  module Reports
    class PosController < BaseController
      before_action { authorize_capability!(:can_view_pos_reports?) }

      def index
        return export_report("pos") if request.format.csv?
        @report = ::Reports::PosSummary.new(@date_range).call
      end
    end
  end
end
