module Admin
  module Users
    class Invite
      Result = Data.define(:success?, :user, :invitation, :token, :errors)

      def initialize(actor:, attributes:)
        @actor, @attributes = actor, attributes
      end

      def call
        return failure("غير مصرح") unless @actor&.can_manage_users?
        token = SecureRandom.urlsafe_base64(32)
        user = nil
        invitation = User.transaction do
          user = User.create!(@attributes.merge(active: false, password: SecureRandom.base64(48)))
          invitation = user.user_invitations.create!(invited_by: @actor, token_digest: UserInvitation.digest(token),
            sent_at: Time.current, expires_at: UserInvitation::EXPIRY.from_now)
          UserAuditEvent.create!(user:, actor: @actor, action: "invited", new_values: { role: user.role })
          invitation
        end
        InvitationDeliveryJob.perform_later(invitation.id, token)
        Result.new(success?: true, user:, invitation:, token:, errors: [])
      rescue ActiveRecord::RecordInvalid => error
        Result.new(success?: false, user: user || error.record, invitation: nil, token: nil,
          errors: error.record.errors.full_messages)
      end

      private

      def failure(message) = Result.new(success?: false, user: nil, invitation: nil, token: nil, errors: [ message ])
    end
  end
end
