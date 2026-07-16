module Staff
  class FulfilmentsController < DeliveryBaseController
    before_action :set_fulfilment, only: %i[show assign transition]
    def index
      scope = Fulfilment.includes(:assigned_to, order: %i[delivery_zone delivery_slot]).order(created_at: :desc)
      scope = scope.where(status: params[:status]) if Fulfilment.statuses.key?(params[:status])
      @pagy, @fulfilments = pagy(scope, limit: 25)
    end
    def show; end
    def assign
      assignee = User.where(active: true, role: %i[order_manager admin]).find_by(id: params[:assigned_to_id])
      result = Delivery::AssignFulfilment.new(order: @fulfilment.order, actor: current_user, assigned_to: assignee,
        internal_notes: params[:internal_notes], lock_version: params[:lock_version]).call
      redirect_to staff_fulfilment_path(@fulfilment), status: :see_other, flash: { result.success? ? :notice : :alert => result.success? ? "تم إسناد مهمة التوصيل" : result.errors.join("، ") }
    end
    def transition
      result = Delivery::UpdateFulfilment.new(fulfilment: @fulfilment, actor: current_user, to_status: params[:to_status], lock_version: params[:lock_version]).call
      redirect_to staff_fulfilment_path(@fulfilment), status: :see_other, flash: { result.success? ? :notice : :alert => result.success? ? "تم تحديث مهمة التوصيل" : result.errors.join("، ") }
    end
    private
    def set_fulfilment = @fulfilment = Fulfilment.includes(:assigned_to, :delivery_zone, :delivery_slot, order: %i[order_address items events]).find(params[:id])
  end
end
