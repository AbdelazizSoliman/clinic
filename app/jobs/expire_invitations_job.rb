class ExpireInvitationsJob < ApplicationJob
  queue_as :maintenance

  def perform
    JobHeartbeat.track(self.class.name) do
      UserInvitation.where(accepted_at: nil, revoked_at: nil).where(expires_at: ..Time.current)
        .update_all(revoked_at: Time.current, updated_at: Time.current)
    end
  end
end
