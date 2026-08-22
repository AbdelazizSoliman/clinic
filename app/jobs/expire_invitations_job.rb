class ExpireInvitationsJob < ApplicationJob
  queue_as :maintenance

  def perform(organization_id = nil)
    return fan_out unless organization_id
    with_organization(organization_id) do
    JobHeartbeat.track(self.class.name) do
      UserInvitation.where(accepted_at: nil, revoked_at: nil).where(expires_at: ..Time.current)
        .update_all(revoked_at: Time.current, updated_at: Time.current)
    end
    end
  end

  private

  def fan_out
    Organization.unscoped.active.find_each { |organization| self.class.perform_later(organization.id) }
  end
end
