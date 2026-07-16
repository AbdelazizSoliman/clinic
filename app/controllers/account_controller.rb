class AccountController < ApplicationController
  before_action :authenticate_user!

  def show
    @addresses = current_user.addresses.where(active: true)
    @default_address = @addresses.find_by(default: true)
    @recent_orders = current_user.orders.order(submitted_at: :desc).limit(3)
    @awaiting_follow_ups = OrderFollowUp.joins(:order).where(orders: { user_id: current_user.id }, status: :awaiting_customer)
    @unread_notifications_count = current_user.notifications.unread.count
  end

  def edit; end

  def update
    attributes = account_params
    DemoMode::SafetyPolicy.protect_demo_account!(current_user, attributes:)
    updated = if attributes[:email].present? && attributes[:email] != current_user.email
      current_user.update_with_password(attributes)
    else
      attributes.delete(:current_password)
      current_user.update(attributes)
    end

    if updated
      redirect_to account_path, notice: "تم تحديث بيانات الحساب بنجاح"
    else
      render :edit, status: :unprocessable_entity
    end
  rescue DemoMode::SafetyPolicy::ProtectedActionError => error
    redirect_to edit_account_path, alert: error.message, status: :see_other
  end

  private

  def account_params
    params.require(:user).permit(:first_name, :last_name, :mobile_number, :email, :current_password)
  end
end
