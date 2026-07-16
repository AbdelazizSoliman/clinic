module Staff
  class DashboardController < BaseController
    def index
      @counts = Order.statuses.keys.index_with { |status| Order.where(status:).count }
      @awaiting_prescriptions = Prescription.where(status: %i[submitted under_review]).count
      @active_reservations = InventoryReservation.active.count
    end
  end
end
