module Reports
  class CleanupExpiredExportsJob < ApplicationJob
    queue_as :maintenance

    def perform
      JobHeartbeat.track(self.class.name) do
        ReportExport.completed.where(expires_at: ..Time.current).find_each do |export|
          export.file.purge
          export.update!(status: :expired)
        end
      end
    end
  end
end
