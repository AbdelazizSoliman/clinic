class CustomerReturnsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_order

  def new
    return head :not_found unless @order.delivered?
    @return_request = ReturnRequest.new
  end

  def create
    result = Returns::Create.new(source: @order, actor: current_user, items: item_specs,
      customer_notes: params.dig(:return_request, :customer_notes)).call
    if result.success?
      redirect_to order_path(@order), notice: "تم إرسال طلب المرتجع #{result.record.number}", status: :see_other
    else
      @return_request = result.record || ReturnRequest.new
      flash.now[:alert] = result.errors.join("، ")
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_order = @order = current_user.orders.includes(items: :return_items).find_by!(number: params[:order_number])
  def item_specs
    params.fetch(:items, {}).values.filter_map do |value|
      permitted = value.permit(:source_item_id, :quantity, :reason, :condition, :reason_notes).to_h
      permitted if permitted["quantity"].to_i.positive?
    end
  end
end
