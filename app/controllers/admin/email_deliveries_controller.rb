module Admin
  class EmailDeliveriesController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_admin!
    layout "admin"

    def index
      @deliveries = TransactionalEmailDelivery.includes(:user).order(updated_at: :desc).limit(100)
    end

    def retry
      delivery = TransactionalEmailDelivery.find(params[:id])
      return head(:unprocessable_entity) unless delivery.failed? && delivery.mailer == "NotificationMailer"
      delivery.update!(status: :queued, queued_at: Time.current)
      TransactionalEmailDeliveryJob.perform_later(delivery.id)
      SecurityEvent.record("email_delivery_retried", user: delivery.user, actor: current_user,
        request: request, metadata: { action: delivery.action })
      redirect_to admin_email_deliveries_path, notice: "تمت إعادة محاولة الإرسال.", status: :see_other
    end

    private

    def authorize_admin!
      head(:not_found) unless current_user.admin?
    end
  end
end
