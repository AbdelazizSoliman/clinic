module Api
  module V1
    class PurchaseOrdersController < BaseController
      before_action -> { require_scope!("purchasing:read") }

      def index
        orders = paginate(PurchaseOrder.includes(:supplier, :branch).order(created_at: :desc))
        render json: { data: orders.map { |order| serialize(order) }, meta: { page:, per_page: page_size } }
      end

      def show
        render json: { data: serialize(PurchaseOrder.find(params[:id])) }
      rescue ActiveRecord::RecordNotFound
        render_error("not_found", "أمر الشراء غير موجود", :not_found)
      end

      private

      def serialize(order)
        { id: order.id, number: order.number, branch_id: order.branch_id, supplier_id: order.supplier_id,
          status: order.status, total_cents: order.total_cents, expected_at: order.expected_at }
      end
    end
  end
end
