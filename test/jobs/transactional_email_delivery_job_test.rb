require "test_helper"
require "minitest/mock"

class TransactionalEmailDeliveryJobTest < ActiveJob::TestCase
  test "enqueue deduplicates and successful delivery stores no payload" do
    user = users(:customer)
    notification = Notification.create!(user:, notifiable: products(:skin_product), kind: "order_confirmed",
      title: "اختبار", body: "رسالة آمنة")
    first = EmailDeliveries::Enqueue.call(user:, notification:, mailer: "NotificationMailer",
      action: "customer_update", deduplication_key: "business:1")
    second = EmailDeliveries::Enqueue.call(user:, notification:, mailer: "NotificationMailer",
      action: "customer_update", deduplication_key: "business:1")
    assert_equal first, second
    fake_message = Object.new
    fake_message.define_singleton_method(:deliver_now) { true }
    fake_proxy = Object.new
    fake_proxy.define_singleton_method(:customer_update) { fake_message }
    NotificationMailer.stub(:with, fake_proxy) { TransactionalEmailDeliveryJob.perform_now(first.id) }
    assert first.reload.delivered?
    assert_not_includes first.attributes.to_json, "رسالة آمنة"
  end

  test "failure records only exception class" do
    delivery = TransactionalEmailDelivery.create!(user: users(:customer), mailer: "Unsupported",
      action: "none", status: :queued, queued_at: Time.current, deduplication_key: "failed:1")
    TransactionalEmailDeliveryJob.perform_now(delivery.id)
    assert delivery.reload.failed?
    assert_equal "ArgumentError", delivery.last_error_class
  end
end
