module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_api!
      before_action :enforce_rate_limit!
      around_action :with_tenant

      private

      def authenticate_api!
        plaintext = request.authorization.to_s.delete_prefix("Bearer ")
        @api_token = ApiToken.authenticate(plaintext)
        render_error("unauthorized", "بيانات اعتماد API غير صالحة", :unauthorized) unless @api_token
      end

      def with_tenant
        return unless @api_token
        Current.set(organization: @api_token.organization) do
          @api_token.update_column(:last_used_at, Time.current)
          yield
        end
      ensure
        Current.reset
      end

      def require_scope!(scope)
        render_error("forbidden_scope", "صلاحية API المطلوبة غير متاحة", :forbidden) unless @api_token.allows?(scope)
      end

      def enforce_rate_limit!
        return unless @api_token
        bucket = Time.current.to_i / 60
        key = "api-rate:#{@api_token.api_client_id}:#{bucket}"
        count = Rails.cache.increment(key, 1, expires_in: 2.minutes) || 1
        render_error("rate_limited", "تم تجاوز حد الطلبات", :too_many_requests) if count > @api_token.api_client.rate_limit_per_minute
      end

      def idempotent(action)
        key = request.headers["Idempotency-Key"].to_s
        return render_error("idempotency_key_required", "مفتاح Idempotency-Key مطلوب", :unprocessable_entity) if key.blank?
        digest = Digest::SHA256.hexdigest(request.raw_post)
        existing = ApiIdempotencyRecord.find_by(api_client: @api_token.api_client, action:, key:)
        if existing
          return render_error("idempotency_conflict", "أعيد استخدام المفتاح بطلب مختلف", :conflict) if existing.request_digest != digest
          return render json: existing.response_body, status: existing.response_status
        end
        status, body, stored_body = yield
        ApiIdempotencyRecord.create!(organization: Current.organization, api_client: @api_token.api_client,
          action:, key:, request_digest: digest, response_status: status, response_body: stored_body || body)
        render json: body, status:
      rescue ActiveRecord::RecordNotUnique
        retry
      end

      def render_error(code, message, status, fields: nil)
        render json: { error: { code:, message:, fields:, request_id: request.request_id }.compact }, status:
      end

      def page_size = params.fetch(:per_page, 25).to_i.clamp(1, 100)
      def page = params.fetch(:page, 1).to_i.clamp(1, 1_000_000)
      def paginate(scope) = scope.limit(page_size).offset((page - 1) * page_size)
    end
  end
end
