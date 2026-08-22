require "test_helper"

class TenantContextJobsTest < ActiveJob::TestCase
  test "recurring tenant jobs fan out with explicit organization ids" do
    other = Organization.create!(code: "JOB-OTHER", name: "Job Other", active: true,
      timezone: "Africa/Cairo", currency: "EGP", locale: "ar")

    assert_enqueued_with(job: ExpireInventoryReservationsJob, args: [ organizations(:default).id ]) do
      ExpireInventoryReservationsJob.perform_now
    end
    assert_enqueued_with(job: ExpireInventoryReservationsJob, args: [ other.id ])
  end

  test "record job establishes and clears tenant context" do
    delivery = TransactionalEmailDelivery.create!(user: users(:customer), mailer: "Unsupported", action: "none",
      status: :queued, queued_at: Time.current, deduplication_key: "tenant-context-job")
    Current.organization = Organization.create!(code: "STALE", name: "Stale", active: true,
      timezone: "Africa/Cairo", currency: "EGP", locale: "ar")

    TransactionalEmailDeliveryJob.perform_now(delivery.organization_id, delivery.id)

    assert_nil Current.organization
    assert delivery.reload.failed?
  end
end
