require "test_helper"
require "minitest/mock"

class WebhookSecurityTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  test "rejects loopback and private webhook targets" do
    %w[https://localhost/hook https://127.0.0.1/hook https://[::1]/hook https://169.254.169.254/hook
      https://10.0.0.1/hook https://172.16.0.1/hook https://192.168.1.1/hook https://[fc00::1]/hook
      http://203.0.113.1/hook ftp://203.0.113.1/hook https://user:pass@203.0.113.1/hook].each do |url|
      assert_raises(Webhooks::UrlPolicy::UnsafeUrl) { Webhooks::UrlPolicy.validate!(url) }
    end
  end

  test "HMAC binds timestamp delivery id and body" do
    signature = Webhooks::Signer.call(secret: "secret", timestamp: "123", delivery_id: "delivery", body: "{}")
    assert_equal 64, signature.length
    refute_equal signature, Webhooks::Signer.call(secret: "secret", timestamp: "124", delivery_id: "delivery", body: "{}")
  end

  test "delivery includes signed headers and stores bounded successful response" do
    organization = organizations(:default)
    endpoint, = WebhookEndpoint.build_with_secret(url: "https://203.0.113.20/hook", subscribed_events: [ "order.created" ])
    endpoint.organization = organization
    endpoint.save!
    delivery = endpoint.deliveries.create!(organization:, delivery_id: "delivery-success", event_name: "order.created",
      payload: { order_id: 123 }, status: "pending")
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.body = "x" * 800
    captured = nil
    http = Object.new
    http.define_singleton_method(:request) { |request| captured = request; response }

    Net::HTTP.stub(:start, ->(*_args, **_kwargs, &block) { block.call(http) }) do
      WebhookDeliveryJob.perform_now(organization.id, delivery.id)
    end

    assert_equal "delivered", delivery.reload.status
    assert_equal 500, delivery.response_excerpt.length
    assert_equal "delivery-success", captured["X-Clinic-Delivery"]
    assert_match(/\Asha256=[0-9a-f]{64}\z/, captured["X-Clinic-Signature"])
    assert captured["X-Clinic-Timestamp"].present?
  end

  test "failed delivery records retry state without leaking unbounded body" do
    organization = organizations(:default)
    endpoint, = WebhookEndpoint.build_with_secret(url: "https://203.0.113.21/hook", subscribed_events: [ "order.updated" ])
    endpoint.organization = organization
    endpoint.save!
    delivery = endpoint.deliveries.create!(organization:, delivery_id: "delivery-failure", event_name: "order.updated",
      payload: {}, status: "pending")
    response = Net::HTTPInternalServerError.new("1.1", "500", "Error")
    response.instance_variable_set(:@read, true)
    response.body = "e" * 900
    http = Object.new
    http.define_singleton_method(:request) { |_request| response }

    Net::HTTP.stub(:start, ->(*_args, **_kwargs, &block) { block.call(http) }) do
      assert_raises(Net::ReadTimeout) { WebhookDeliveryJob.new.perform(organization.id, delivery.id) }
    end

    assert_equal "retrying", delivery.reload.status
    assert_equal 1, delivery.attempts
    assert_equal 500, delivery.response_excerpt.length
    assert_equal 1, endpoint.reload.failure_count
  end

  test "publisher selects only current tenant subscribed endpoints and enqueues asynchronously" do
    organization = organizations(:default)
    Current.organization = organization
    subscribed, = WebhookEndpoint.build_with_secret(url: "https://203.0.113.30/hook", subscribed_events: [ "order.created" ])
    subscribed.organization = organization
    subscribed.save!
    ignored, = WebhookEndpoint.build_with_secret(url: "https://203.0.113.31/hook", subscribed_events: [ "order.updated" ])
    ignored.organization = organization
    ignored.save!

    assert_difference -> { WebhookDelivery.count }, 1 do
      assert_enqueued_with(job: WebhookDeliveryJob) do
        Webhooks::Publish.call("order.created", { order_id: 1 })
      end
    end
    assert_equal subscribed, WebhookDelivery.last.webhook_endpoint
  ensure
    Current.reset
  end
end
