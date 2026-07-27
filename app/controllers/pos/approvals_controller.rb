module Pos
  class ApprovalsController < BaseController
    before_action :find_sale

    def prescription
      item = @sale.items.find(params[:item_id])
      result = ApprovePrescription.new(item:, actor: current_user, reason: params[:reason]).call
      redirect_to pos_sale_path(@sale), result.success? ? { notice: "تم اعتماد بند الروشتة" } : { alert: result.errors.join("، ") }
    end

    def discount
      result = ApproveDiscount.new(sale: @sale, actor: current_user,
        amount_cents: params[:amount_cents], reason: params[:reason]).call
      redirect_to pos_sale_path(@sale), result.success? ? { notice: "تم اعتماد الخصم" } : { alert: result.errors.join("، ") }
    end
  end
end
