module Staff
  class FollowUpsController < BaseController
    before_action :set_follow_up, only: :resolve

    def index
      scope = permitted_scope.includes(:opened_by, :messages, order: :user)
      @pagy, @follow_ups = pagy(Staff::FollowUpsQuery.new(scope, params.permit(:status, :kind, :q)).call, limit: 20)
    end

    def create
      order = Order.find_by!(number: params[:order_number])
      result = OrderFollowUps::Open.new(order:, actor: current_user, kind: params[:kind], subject: params[:subject],
        customer_message: params[:customer_message], internal_notes: params[:internal_notes]).call
      redirect_to staff_order_path(order), status: :see_other, flash: { result.success? ? :notice : :alert => result.success? ? "تم فتح متابعة مع العميل" : result.errors.join("، ") }
    end

    def resolve
      result = OrderFollowUps::Resolve.new(follow_up: @follow_up, actor: current_user, message: params[:message], internal: params[:internal] == "1", lock_version: params[:lock_version]).call
      redirect_to staff_follow_ups_path, status: :see_other, flash: { result.success? ? :notice : :alert => result.success? ? "تم حل المتابعة" : result.errors.join("، ") }
    end

    private

    def permitted_scope
      return OrderFollowUp.all if current_user.admin?
      return OrderFollowUp.where(kind: %i[prescription_clarification replacement_requested quantity_confirmation unavailable_item]) if current_user.pharmacist?
      OrderFollowUp.where(kind: %i[delivery_question general])
    end

    def set_follow_up = @follow_up = permitted_scope.find(params[:id])
  end
end
