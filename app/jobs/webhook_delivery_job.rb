require "net/http"

class WebhookDeliveryJob < ApplicationJob
  queue_as :default
  retry_on Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, wait: :polynomially_longer, attempts: 5 do |job, _error|
    organization_id, delivery_id = job.arguments
    delivery = WebhookDelivery.unscoped.find_by(id: delivery_id, organization_id:)
    delivery&.update!(status: "failed", failed_at: Time.current)
  end

  def perform(organization_id, delivery_id)
    with_organization(organization_id) do
      delivery = WebhookDelivery.find(delivery_id)
      endpoint = delivery.webhook_endpoint
      return unless endpoint.active?
      Webhooks::UrlPolicy.validate!(endpoint.url)
      uri = URI.parse(endpoint.url)
      body = delivery.payload.to_json
      timestamp = Time.current.to_i.to_s
      signature = Webhooks::Signer.call(secret: endpoint.encrypted_secret, timestamp:, delivery_id: delivery.delivery_id, body:)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["X-Clinic-Timestamp"] = timestamp
      request["X-Clinic-Delivery"] = delivery.delivery_id
      request["X-Clinic-Signature"] = "sha256=#{signature}"
      request.body = body
      delivery.update!(attempts: delivery.attempts + 1, status: "delivering")
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 5) { |http| http.request(request) }
      delivery.update!(response_status: response.code.to_i, response_excerpt: response.body.to_s.first(500),
        status: response.is_a?(Net::HTTPSuccess) ? "delivered" : "retrying",
        delivered_at: (Time.current if response.is_a?(Net::HTTPSuccess)))
      endpoint.update!(failure_count: 0) if response.is_a?(Net::HTTPSuccess) && endpoint.failure_count.positive?
      endpoint.increment!(:failure_count) unless response.is_a?(Net::HTTPSuccess)
      raise Net::ReadTimeout, "webhook returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    end
  end
end
