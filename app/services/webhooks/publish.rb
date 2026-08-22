module Webhooks
  class Publish
    def self.call(event_name, payload)
      WebhookEndpoint.where(active: true).where("? = ANY(subscribed_events)", event_name).find_each do |endpoint|
        delivery = endpoint.deliveries.create!(organization: endpoint.organization, delivery_id: SecureRandom.uuid,
          event_name:, payload:, status: "pending")
        WebhookDeliveryJob.perform_later(delivery.organization_id, delivery.id)
      end
    end
  end
end
