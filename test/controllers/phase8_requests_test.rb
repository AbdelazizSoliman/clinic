require "test_helper"

class Phase8RequestsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "notifications are scoped to current user and can be marked read" do
    customer = users(:customer)
    own = customer.notifications.create!(notifiable: customer, kind: "order_confirmed", title: "تحديث", body: "طلبك مؤكد")
    foreign = users(:other_customer).notifications.create!(notifiable: users(:other_customer), kind: "order_confirmed", title: "خاص", body: "لا يظهر")
    sign_in customer
    get notifications_path
    assert_response :success
    assert_includes response.body, "طلبك مؤكد"
    assert_not_includes response.body, "لا يظهر"
    patch notification_path(foreign)
    assert_response :not_found
    patch notification_path(own)
    assert_redirected_to notifications_path
    assert own.reload.read_at
  end

  test "customer cannot access staff follow-up queue" do
    sign_in users(:customer)
    get staff_follow_ups_path
    assert_response :not_found
  end

  test "expiry job invokes idempotent batch service" do
    assert_nothing_raised { ExpireInventoryReservationsJob.perform_now }
    assert_nothing_raised { ExpireInventoryReservationsJob.perform_now }
  end
end
