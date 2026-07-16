require "test_helper"

class CustomerFollowupAndExpiryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @customer = users(:customer)
    @pharmacist = users(:pharmacist)
    @manager = users(:order_manager)
  end

  test "staff opens customer follow-up customer responds and pharmacist resolves" do
    order = create_order(products(:featured), prescription: true)
    opened = OrderFollowUps::Open.new(order:, actor: @pharmacist, kind: :prescription_clarification,
      subject: "صورة أوضح", customer_message: "نحتاج توضيح الجرعة").call
    assert opened.success?
    follow_up = opened.follow_up
    assert follow_up.awaiting_customer?
    assert @customer.notifications.exists?(kind: "follow_up_requested")
    assert_not OrderFollowUps::Respond.new(follow_up:, customer: users(:other_customer), body: "رد").call.success?
    assert OrderFollowUps::Respond.new(follow_up:, customer: @customer, body: "الجرعة مرة يوميًا").call.success?
    assert follow_up.reload.customer_responded?
    assert OrderFollowUps::Resolve.new(follow_up:, actor: @pharmacist).call.success?
    assert follow_up.reload.resolved?
    assert order.events.exists?(event_type: "follow_up_resolved")
  end

  test "partial approval automatically opens follow-up" do
    order = create_order(products(:featured), prescription: true)
    result = Prescriptions::Review.new(prescription: order.prescription, actor: @pharmacist,
      decision: "partially_approved", customer_message: "أكد الجرعة المطلوبة").call
    assert result.success?, result.errors.inspect
    assert order.follow_ups.awaiting_customer.exists?
    assert order.reload.pending_prescription?
  end

  test "customer cancellation releases reservations and is idempotent" do
    order = create_order(products(:skin_product))
    result = Orders::Cancel.new(order:, actor: @customer, reason: "لم أعد بحاجة إليه", source: "customer").call
    assert result.success?, result.errors.inspect
    assert order.reload.cancelled?
    assert order.inventory_reservations.released.exists?
    assert_equal 1, order.events.where(event_type: "customer_cancelled").count
    assert Orders::Cancel.new(order:, actor: @customer, reason: "مكرر", source: "customer").call.success?
    assert_equal 1, order.events.where(event_type: "customer_cancelled").count
  end

  test "expiry cancels submitted order but skips confirmed order" do
    expired = create_order(products(:skin_product))
    expired.inventory_reservations.update_all(expires_at: 1.minute.ago)
    confirmed = create_order(products(:skin_product))
    assert Orders::Transition.new(order: confirmed, actor: @manager, to_status: "confirmed").call.success?
    confirmed.inventory_reservations.update_all(expires_at: 1.minute.ago)
    result = Inventory::ExpireReservations.new.call
    assert_equal 1, result.processed
    assert expired.reload.cancelled?
    assert confirmed.reload.confirmed?
    assert expired.events.exists?(event_type: "reservations_expired")
  end

  test "admin extension uses policy and requires reason" do
    order = create_order(products(:skin_product))
    assert_not Inventory::ExtendReservations.new(order:, actor: users(:admin), context: :admin).call.success?
    result = Inventory::ExtendReservations.new(order:, actor: users(:admin), context: :admin, reason: "انتظار تواصل موثق").call
    assert result.success?
    assert order.inventory_reservations.active.where.not(expires_at: nil).exists?
    assert order.events.exists?(event_type: "reservations_extended", customer_visible: false)
  end

  private

  def create_order(product, prescription: false)
    product.update!(requires_prescription: true) if prescription
    cart = @customer.carts.active.first || @customer.carts.create!(currency: "EGP")
    cart.items.delete_all
    cart.items.create!(product:, quantity: 1)
    cart.ensure_checkout_submission_token!
    files = prescription ? [ Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/prescription.pdf"), "application/pdf") ] : []
    result = Orders::CreateFromCart.new(user: @customer, cart:, address_id: addresses(:home).id,
      delivery_method: "standard", payment_method: "cash_on_delivery", submission_token: cart.checkout_submission_token,
      prescription_files: files).call
    assert result.success?, result.errors.inspect
    result.order
  end
end
