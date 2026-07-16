class TransactionalEmailDeliveryJob < ApplicationJob
  queue_as :mailers
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(delivery_id)
    delivery = TransactionalEmailDelivery.find(delivery_id)
    return if delivery.delivered? || delivery.cancelled?
    delivery.update!(status: :processing, attempts_count: delivery.attempts_count + 1, last_error_class: nil)
    mail_for(delivery).deliver_now
    delivery.update!(status: :delivered, delivered_at: Time.current, failed_at: nil)
  rescue => error
    delivery&.update!(status: :failed, failed_at: Time.current, last_error_class: error.class.name)
    Errors::Reporter.capture(error, context: { job_class: self.class.name })
    raise
  end

  private

  def mail_for(delivery)
    raise ArgumentError, "UnsupportedMailer" unless delivery.mailer == "NotificationMailer" && delivery.action == "customer_update"
    NotificationMailer.with(notification: delivery.notification).customer_update
  end
end
