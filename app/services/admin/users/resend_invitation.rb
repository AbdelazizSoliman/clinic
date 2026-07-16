module Admin
  module Users
    class ResendInvitation
      def initialize(actor:, user:)
        @actor, @user = actor, user
      end

      def call
        return false unless @actor.can_manage_users? && !@user.active?
        token = SecureRandom.urlsafe_base64(32)
        invitation = UserInvitation.transaction do
          @user.user_invitations.where(accepted_at: nil, revoked_at: nil).update_all(revoked_at: Time.current)
          created = @user.user_invitations.create!(invited_by: @actor, token_digest: UserInvitation.digest(token),
            sent_at: Time.current, expires_at: UserInvitation::EXPIRY.from_now)
          UserAuditEvent.create!(user: @user, actor: @actor, action: "invitation_resent")
          created
        end
        InvitationDeliveryJob.perform_later(invitation.id, token)
        true
      end
    end
  end
end
