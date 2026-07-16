module Admin
  module Reports
    class DashboardController < BaseController
      def index
        head(:not_found) unless current_user.can_view_business_reports? || current_user.can_view_inventory_reports? || current_user.can_view_prescription_reports?
        @sales = ::Reports::SalesSummary.new(@date_range).call if current_user.can_view_business_reports?
        @inventory = ::Reports::InventorySummary.new(@date_range).call if current_user.can_view_inventory_reports?
        @prescriptions = ::Reports::PrescriptionPerformance.new(@date_range).call if current_user.can_view_prescription_reports?
        @fulfilments = ::Reports::FulfilmentPerformance.new(@date_range).call if current_user.can_view_fulfilment_reports?
      end
    end
  end
end
