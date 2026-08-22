module Api
  module V1
    class ReturnsController < BaseController
      before_action -> { require_scope!("orders:read") }

      def index
        returns = paginate(ReturnRequest.order(created_at: :desc))
        render json: { data: returns.map { |record| serialize(record) }, meta: { page:, per_page: page_size } }
      end

      def show
        render json: { data: serialize(ReturnRequest.find(params[:id])) }
      rescue ActiveRecord::RecordNotFound
        render_error("not_found", "المرتجع غير موجود", :not_found)
      end

      private

      def serialize(record)
        { id: record.id, number: record.number, branch_id: record.branch_id, source_type: record.source_type,
          status: record.status, refundable_cents: record.refundable_cents, refunded_cents: record.refunded_cents,
          created_at: record.created_at.iso8601 }
      end
    end
  end
end
