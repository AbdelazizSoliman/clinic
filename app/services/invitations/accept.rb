module Invitations
  class Accept
    Result = Data.define(:success?, :user, :errors)

    def initialize(token:, password:, password_confirmation:)
      @token, @password, @password_confirmation = token.to_s, password, password_confirmation
    end

    def call
      invitation = UserInvitation.find_by(token_digest: UserInvitation.digest(@token))
      return failure unless invitation&.usable?
      user = invitation.user
      UserInvitation.transaction do
        invitation.lock!
        return failure unless invitation.usable?
        user.assign_attributes(password: @password, password_confirmation: @password_confirmation, active: true)
        unless user.save
          invitation.increment!(:attempts_count)
          return Result.new(success?: false, user:, errors: user.errors.full_messages)
        end
        invitation.update!(accepted_at: Time.current)
        UserAuditEvent.create!(user:, actor: nil, action: "invitation_accepted")
      end
      Result.new(success?: true, user:, errors: [])
    end

    private

    def failure = Result.new(success?: false, user: nil, errors: [ "رابط الدعوة غير صالح أو منتهي" ])
  end
end
