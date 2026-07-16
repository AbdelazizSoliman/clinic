require "test_helper"

class DeliveryOperationsTest < ActiveSupport::TestCase
  test "zone matcher normalizes an owned address and rejects inactive zones" do
    result = Delivery::ZoneMatcher.call(addresses(:home))
    assert result.matched?
    assert_equal delivery_zones(:cairo), result.zone
    assert_not Delivery::ZoneMatcher.call(addresses(:other_home)).matched?
  end

  test "zone fees include method surcharge and respect free threshold" do
    zone = delivery_zones(:giza)
    method = delivery_methods(:giza_scheduled)
    assert_equal 4_000, zone.fee_for(10_000, method: method.additional_fee_cents)
    zone.update!(free_delivery_threshold_cents: 5_000)
    assert_equal 1_000, zone.fee_for(10_000, method: method.additional_fee_cents)
  end

  test "delivery capabilities are restricted to operations and admin" do
    assert users(:order_manager).can_manage_delivery?
    assert users(:admin).can_assign_delivery?
    assert_not users(:customer).can_manage_delivery?
    assert_not users(:pharmacist).can_manage_delivery?
    assert_not users(:inventory_manager).can_manage_delivery?
  end

  test "scheduled order snapshots zone fee slot and creates fulfilment" do
    user = users(:customer)
    cart = carts(:customer_cart)
    cart.items.delete_all
    cart.update!(checkout_submission_token: SecureRandom.urlsafe_base64(32))
    cart.items.create!(product: products(:skin_product), quantity: 1)
    slot = delivery_slots(:cairo_tomorrow)
    result = Orders::CreateFromCart.new(user:, cart:, address_id: addresses(:home).id,
      delivery_method: "scheduled", delivery_slot_id: slot.id, payment_method: "cash_on_delivery",
      submission_token: cart.checkout_submission_token).call
    assert result.success?, result.errors.inspect
    assert_equal "cairo-east", result.order.delivery_zone_code
    assert_equal slot.scheduled_at, result.order.scheduled_for
    assert_equal 1_000, result.order.delivery_fee_cents
    assert_equal 1, slot.reload.booked_count
    assert result.order.fulfilment.unassigned?
  end

  test "assignment and fulfilment progression are authorized and audited" do
    user = users(:customer)
    cart = carts(:customer_cart)
    cart.items.delete_all
    cart.update!(checkout_submission_token: SecureRandom.urlsafe_base64(32))
    cart.items.create!(product: products(:skin_product), quantity: 1)
    result = Orders::CreateFromCart.new(user:, cart:, address_id: addresses(:home).id, delivery_method: "standard",
      payment_method: "cash_on_delivery", submission_token: cart.checkout_submission_token).call
    assert result.success?, result.errors.inspect
    order = result.order
    fulfilment = order.fulfilment
    denied = Delivery::AssignFulfilment.new(order:, actor: users(:pharmacist), assigned_to: users(:order_manager)).call
    assert_not denied.success?
    assigned = Delivery::AssignFulfilment.new(order:, actor: users(:admin), assigned_to: users(:order_manager)).call
    assert assigned.success?
    assert fulfilment.reload.assigned?
    assert Delivery::UpdateFulfilment.new(fulfilment:, actor: users(:order_manager), to_status: "picking").call.success?
    assert order.events.exists?(event_type: "fulfilment_picking")
  end
end
