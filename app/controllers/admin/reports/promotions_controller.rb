module Admin::Reports
  class PromotionsController < BaseController
    before_action { head(:not_found) unless current_user.admin? }
    def index
      return export_report("promotions") if request.format.csv?
      @report = ::Reports::PromotionPerformance.new(@date_range).call
    end
  end
end
