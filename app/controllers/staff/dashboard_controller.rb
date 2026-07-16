module Staff
  class DashboardController < BaseController
    def index
      @counts = Order.statuses.keys.index_with { |status| Order.where(status:).count }
      @awaiting_prescriptions = Prescription.where(status: %i[submitted under_review]).count
      @active_reservations = InventoryReservation.active.count
      @awaiting_customer_responses = OrderFollowUp.customer_responded.count
      @overdue_follow_ups = OrderFollowUp.overdue.count
      @expiring_reservations = InventoryReservation.expiring_before(2.hours.from_now).count
      @unread_notifications = current_user.notifications.unread.count
    end
  end
end
