module Api
  module V1
    class InventoryController < BaseController
      before_action -> { require_scope!("inventory:read") }
      def index
        relation = InventoryBatch.includes(:product, :branch).order(:branch_id, :product_id, :expiry_date)
        relation = relation.where(branch_id: params[:branch_id]) if params[:branch_id].present?
        batches = paginate(relation)
        render json: { data: batches.map { |b| { batch_id: b.id, branch_id: b.branch_id, product_id: b.product_id,
          on_hand: b.on_hand_quantity, reserved: b.reserved_quantity, available: b.available_quantity, expiry_date: b.expiry_date } },
          meta: { page:, per_page: page_size } }
      end
    end
  end
end
