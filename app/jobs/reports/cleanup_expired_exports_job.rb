module Reports
  class CleanupExpiredExportsJob < ApplicationJob
    queue_as :maintenance

    def perform(organization_id = nil)
      return fan_out unless organization_id
      with_organization(organization_id) do
      JobHeartbeat.track(self.class.name) do
        ReportExport.completed.where(expires_at: ..Time.current).find_each do |export|
          export.file.purge
          export.update!(status: :expired)
        end
      end
      end
    end

    private

    def fan_out
      Organization.unscoped.active.find_each { |organization| self.class.perform_later(organization.id) }
    end
  end
end
