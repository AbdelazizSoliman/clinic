class InvitationDeliveryJob < ApplicationJob
  self.log_arguments = false
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(invitation_id, token)
    invitation = UserInvitation.find_by(id: invitation_id)
    return unless invitation&.usable?
    delivery = TransactionalEmailDelivery.find_or_create_by!(deduplication_key: "invitation:#{invitation.id}:#{invitation.sent_at.to_i}") do |record|
      record.assign_attributes(user: invitation.user, mailer: "UserInvitationMailer", action: "invite",
        status: :queued, queued_at: Time.current)
    end
    return if delivery.delivered? || delivery.cancelled?
    delivery.update!(status: :processing, attempts_count: delivery.attempts_count + 1)
    UserInvitationMailer.with(invitation:, token:).invite.deliver_now
    delivery.update!(status: :delivered, delivered_at: Time.current, failed_at: nil, last_error_class: nil)
  rescue => error
    delivery&.update!(status: :failed, failed_at: Time.current, last_error_class: error.class.name)
    Errors::Reporter.capture(error, context: { job_class: self.class.name })
    raise
  end
end
