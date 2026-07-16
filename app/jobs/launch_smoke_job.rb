class LaunchSmokeJob < ApplicationJob
  queue_as :maintenance

  def perform
    Rails.logger.info(event_type: "launch_smoke_job", job_class: self.class.name)
  end
end
