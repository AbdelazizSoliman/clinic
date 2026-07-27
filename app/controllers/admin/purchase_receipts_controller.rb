module Admin
  class PurchaseReceiptsController < BaseController
    def create
      order = PurchaseOrder.find_by!(number: params[:purchase_order_number])
      quantities = order.items.to_h { |item| [ item.id.to_s, params.dig(:quantities, item.id.to_s) ] }
      result = Purchasing::Receive.new(purchase_order: order, actor: current_user,
        quantities:, batches: params[:batches]&.to_unsafe_h || {}, idempotency_key: params[:idempotency_key],
        supplier_document_number: params[:supplier_document_number], notes: params[:notes], lock_version: params[:lock_version]).call
      redirect_to admin_purchase_order_path(order), status: :see_other,
        flash: { result.success? ? :notice : :alert => result.success? ? "تم تثبيت الاستلام وتحديث المخزون" : result.errors.join("، ") }
    end
  end
end
