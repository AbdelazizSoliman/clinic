class ExpireInventoryReservationsJob < ApplicationJob
  queue_as :default

  def perform(organization_id = nil)
    return fan_out unless organization_id
    with_organization(organization_id) do
    JobHeartbeat.track(self.class.name) do
      result = Inventory::ExpireReservations.new.call
      Rails.logger.info(event_type: "reservation_expiry", job_class: self.class.name,
        processed: result.processed, failed: result.failed.size)
      result.processed
    end
    end
  end

  private

  def fan_out
    Organization.unscoped.active.find_each { |organization| self.class.perform_later(organization.id) }
  end
end
