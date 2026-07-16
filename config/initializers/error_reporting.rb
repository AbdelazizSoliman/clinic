class SafeErrorSubscriber
  def report(error, handled:, severity:, context:, source: nil)
    Errors::Reporter.capture(error, context: {
      request_id: context[:request]&.request_id,
      actor_role: context[:request]&.env&.dig("warden")&.user&.role,
      job_class: source == "application.active_job" ? context[:job]&.class&.name : nil
    })
  end
end

Rails.error.subscribe(SafeErrorSubscriber.new)
