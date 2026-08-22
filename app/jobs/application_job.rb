class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  private

  def with_organization(organization_id)
    organization = Organization.unscoped.find(organization_id)
    Current.set(organization:) { yield organization }
  ensure
    Current.reset
  end
end
