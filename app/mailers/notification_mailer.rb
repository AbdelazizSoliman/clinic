class NotificationMailer < ApplicationMailer
  EMAILABLE = %w[follow_up_requested prescription_approved prescription_rejected order_confirmed order_ready order_cancelled].freeze

  def customer_update
    @notification = params[:notification]
    @user = @notification.user
    @order = @notification.notifiable.is_a?(Order) ? @notification.notifiable : @notification.notifiable.order
    mail(to: @user.email, subject: @notification.title)
  end
end
