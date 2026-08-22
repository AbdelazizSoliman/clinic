module Api
  module V1
    class WebhookEndpointsController < BaseController
      before_action -> { require_scope!("webhooks:manage") }
      before_action :set_endpoint, only: %i[show update destroy rotate_secret]

      def index
        endpoints = paginate(WebhookEndpoint.order(:id))
        render json: { data: endpoints.map { |endpoint| serialize(endpoint) }, meta: { page:, per_page: page_size } }
      end

      def show
        render json: { data: serialize(@endpoint) }
      end

      def create
        idempotent("webhooks.create") do
          endpoint, secret = WebhookEndpoint.build_with_secret(endpoint_params)
          endpoint.organization = Current.organization
          endpoint.save!
          audit(endpoint, "webhook_endpoint_created")
          [ 201, { data: serialize(endpoint).merge(secret:) }, { data: serialize(endpoint) } ]
        rescue ActiveRecord::RecordInvalid => error
          [ 422, { error: { code: "validation_failed", message: "تعذر إنشاء webhook",
            fields: error.record.errors.to_hash, request_id: request.request_id } } ]
        end
      end

      def update
        idempotent("webhooks.update:#{@endpoint.id}") do
          @endpoint.update!(endpoint_params)
          audit(@endpoint, "webhook_endpoint_updated")
          [ 200, { data: serialize(@endpoint) } ]
        rescue ActiveRecord::RecordInvalid => error
          [ 422, { error: { code: "validation_failed", message: "تعذر تحديث webhook",
            fields: error.record.errors.to_hash, request_id: request.request_id } } ]
        end
      end

      def destroy
        idempotent("webhooks.deactivate:#{@endpoint.id}") do
          @endpoint.update!(active: false)
          audit(@endpoint, "webhook_endpoint_deactivated")
          [ 200, { data: serialize(@endpoint) } ]
        end
      end

      def rotate_secret
        idempotent("webhooks.rotate:#{@endpoint.id}") do
          secret = SecureRandom.urlsafe_base64(32)
          @endpoint.update!(encrypted_secret: secret, secret_digest: Digest::SHA256.hexdigest(secret))
          audit(@endpoint, "webhook_secret_rotated")
          [ 200, { data: serialize(@endpoint).merge(secret:) }, { data: serialize(@endpoint) } ]
        end
      end

      private

      def set_endpoint
        @endpoint = WebhookEndpoint.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_error("not_found", "Webhook غير موجود", :not_found)
      end

      def endpoint_params
        params.require(:webhook_endpoint).permit(:url, :active, subscribed_events: [])
      end

      def serialize(endpoint)
        { id: endpoint.id, url: endpoint.url, subscribed_events: endpoint.subscribed_events,
          active: endpoint.active?, failure_count: endpoint.failure_count, created_at: endpoint.created_at.iso8601 }
      end

      def audit(endpoint, action)
        IntegrationAuditEvent.create!(organization: Current.organization, api_client: @api_token.api_client,
          auditable: endpoint, action:, metadata: { url: endpoint.url, subscribed_events: endpoint.subscribed_events })
      end
    end
  end
end
