class JobHeartbeat < ApplicationRecord
  validates :job_name, presence: true, uniqueness: true

  def self.track(job_name)
    heartbeat = find_or_create_by!(job_name:)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    heartbeat.update!(last_started_at: Time.current)
    processed = yield
    heartbeat.update!(last_succeeded_at: Time.current,
      duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round,
      processed_count: processed.to_i, failure_class: nil)
    processed
  rescue => error
    heartbeat&.update!(last_failed_at: Time.current, failure_class: error.class.name)
    raise
  end
end
