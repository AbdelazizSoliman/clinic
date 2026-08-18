module Pos
  class ApprovalsController < BaseController
    before_action :find_sale

    def prescription
      item = @sale.items.find(params[:item_id])
      review_item = Prescriptions::EnsureReview.call(@sale, actor: current_user).items.find_by!(reviewable_item: item)
      substitute = Product.find_by(id: params[:substitute_product_id]) if params[:decision] == "substituted"
      result = Prescriptions::DecideLine.new(item: review_item, actor: current_user,
        decision: params[:decision].presence || "approved", reason: params[:reason],
        notes: params[:notes], substitute_product: substitute,
        physician_instruction_reference: params[:physician_instruction_reference],
        lock_version: params[:lock_version]).call
      redirect_to pos_sale_path(@sale), result.success? ? { notice: "تم حفظ القرار السريري" } : { alert: result.errors.join("، ") }
    end

    def discount
      result = ApproveDiscount.new(sale: @sale, actor: current_user,
        amount_cents: params[:amount_cents], reason: params[:reason]).call
      redirect_to pos_sale_path(@sale), result.success? ? { notice: "تم اعتماد الخصم" } : { alert: result.errors.join("، ") }
    end
  end
end
