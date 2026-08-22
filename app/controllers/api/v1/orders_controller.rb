module Api
  module V1
    class OrdersController < BaseController
      before_action -> { require_scope!("orders:read") }, only: %i[index show]
      before_action -> { require_scope!("orders:write") }, only: :cancel
      def index
        orders = paginate(Order.order(created_at: :desc))
        render json: { data: orders.map { |order| serialize(order) }, meta: { page:, per_page: page_size } }
      end
      def show
        render json: { data: serialize(Order.find(params[:id])) }
      rescue ActiveRecord::RecordNotFound
        render_error("not_found", "الطلب غير موجود", :not_found)
      end
      def cancel
        idempotent("orders.cancel") do
          order = Order.find(params[:id])
          result = Orders::Cancel.new(order:, actor: nil, reason: params[:reason], source: "system").call
          result.success? ? [ 200, { data: serialize(result.order.reload) } ] : [ 422, { error: { code: "invalid_transition", message: result.errors.join("، "), request_id: request.request_id } } ]
        end
      rescue ActiveRecord::RecordNotFound
        render_error("not_found", "الطلب غير موجود", :not_found)
      end
      private
      def serialize(order) = { id: order.id, number: order.number, branch_id: order.branch_id, status: order.status,
        total_cents: order.total_cents, created_at: order.created_at.iso8601 }
    end
  end
end
