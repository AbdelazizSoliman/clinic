class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @pagy, @notifications = pagy(current_user.notifications.recent_first, limit: 20)
  end

  def update
    notification = current_user.notifications.find(params[:id])
    notification.read!
    redirect_to notifications_path, status: :see_other
  end

  def mark_all_read
    current_user.notifications.unread.update_all(read_at: Time.current, updated_at: Time.current)
    redirect_to notifications_path, notice: "تم تعليم كل الإشعارات كمقروءة", status: :see_other
  end
end
