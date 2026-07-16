class ExpireInventoryReservationsJob < ApplicationJob
  queue_as :default

  def perform
    result = Inventory::ExpireReservations.new.call
    Rails.logger.info("Reservation expiry processed=#{result.processed} failed=#{result.failed.size}")
  end
end
