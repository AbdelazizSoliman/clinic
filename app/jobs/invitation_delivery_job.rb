class InvitationDeliveryJob < ApplicationJob
  self.log_arguments = false

  def perform(invitation_id, token)
    invitation = UserInvitation.find_by(id: invitation_id)
    return unless invitation&.usable?

    UserInvitationMailer.with(invitation:, token:).invite.deliver_now
  end
end
