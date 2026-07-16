class ExpireInventoryReservationsJob < ApplicationJob
  queue_as :default

  def perform
    JobHeartbeat.track(self.class.name) do
      result = Inventory::ExpireReservations.new.call
      Rails.logger.info(event_type: "reservation_expiry", job_class: self.class.name,
        processed: result.processed, failed: result.failed.size)
      result.processed
    end
  end
end
