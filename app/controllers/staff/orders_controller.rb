module Staff
  class OrdersController < BaseController
    before_action :authorize_operations!, only: :transition
    before_action :set_order, only: %i[show transition]

    def index
      relation = Order.includes(:user, :items, :prescription, :inventory_reservations)
      filters = params.permit(:q, :status, :prescription, :prescription_status, :payment_method, :payment_status, :date_from, :date_to, :sort)
      @pagy, @orders = pagy(Staff::OrdersQuery.new(relation, filters).call, limit: 20)
    end

    def show; end

    def transition
      result = Orders::Transition.new(order: @order, actor: current_user, to_status: params[:to_status], lock_version: params[:lock_version]).call
      redirect_to staff_order_path(@order), status: :see_other, flash: { result.success? ? :notice : :alert => result.success? ? "تم تحديث حالة الطلب" : result.errors.join("، ") }
    end

    private

    def authorize_operations!
      head :not_found unless current_user.can_operate_orders?
    end
    def set_order = @order = Order.includes(:items, :order_address, :events, :inventory_reservations, prescription: { images_attachments: :blob }).find_by!(number: params[:number])
  end
end
