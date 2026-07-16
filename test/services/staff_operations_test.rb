require "test_helper"

class StaffOperationsTest < ActiveSupport::TestCase
  setup do
    @customer = users(:customer)
    @pharmacist = users(:pharmacist)
    @manager = users(:order_manager)
  end

  test "roles expose explicit centralized abilities" do
    assert @pharmacist.can_review_prescriptions?
    assert_not @pharmacist.can_operate_orders?
    assert @manager.can_operate_orders?
    assert_not @manager.can_review_prescriptions?
    assert users(:admin).can_review_prescriptions?
    assert users(:admin).can_operate_orders?
  end

  test "pharmacist approves prescription and customer-visible event advances order" do
    order = prescription_order
    order.prescription.reload
    result = Prescriptions::Review.new(prescription: order.prescription, actor: @pharmacist, decision: "approved", lock_version: order.prescription.lock_version).call
    assert result.success?, result.errors.inspect
    assert order.prescription.reload.approved?
    assert_equal @pharmacist, order.prescription.reviewed_by
    assert order.reload.submitted?
    assert order.events.exists?(event_type: "prescription_approved", customer_visible: true)
    assert order.inventory_reservations.active.exists?
  end

  test "partial approval requires customer message and remains pending" do
    order = prescription_order
    denied = Prescriptions::Review.new(prescription: order.prescription, actor: @pharmacist, decision: "partially_approved").call
    assert_not denied.success?
    result = Prescriptions::Review.new(prescription: order.prescription, actor: @pharmacist, decision: "partially_approved", customer_message: "نحتاج صورة أوضح").call
    assert result.success?
    assert order.prescription.reload.partially_approved?
    assert order.reload.pending_prescription?
  end

  test "rejection requires reason releases reservations and final decision is immutable" do
    order = prescription_order
    assert_not Prescriptions::Review.new(prescription: order.prescription, actor: @pharmacist, decision: "rejected").call.success?
    result = Prescriptions::Review.new(prescription: order.prescription, actor: @pharmacist, decision: "rejected", customer_message: "الروشتة غير صالحة").call
    assert result.success?
    assert order.reload.rejected?
    assert order.inventory_reservations.released.exists?
    assert_not Prescriptions::Review.new(prescription: order.prescription, actor: users(:admin), decision: "approved").call.success?
  end

  test "wrong roles and stale versions are denied" do
    order = prescription_order
    assert_not Prescriptions::Review.new(prescription: order.prescription, actor: @manager, decision: "approved").call.success?
    assert_not Prescriptions::Review.new(prescription: order.prescription, actor: @customer, decision: "approved").call.success?
    result = Prescriptions::Review.new(prescription: order.prescription, actor: @pharmacist, decision: "approved", lock_version: 99).call
    assert_not result.success?
    assert_includes result.errors.join, "أعد تحميل"
  end

  test "order manager follows exact flow and ready consumes stock once" do
    order = normal_order
    stock = products(:skin_product).stock_quantity
    %w[confirmed preparing ready_for_delivery out_for_delivery delivered].each do |target|
      result = Orders::Transition.new(order:, actor: @manager, to_status: target, lock_version: order.lock_version).call
      assert result.success?, result.errors.inspect
      order.reload
    end
    assert order.delivered?
    assert order.inventory_reservations.consumed.exists?
    assert_equal stock - 1, products(:skin_product).reload.stock_quantity
    assert Orders::Transition.new(order:, actor: @manager, to_status: "delivered").call.success?
    assert_not Orders::Transition.new(order:, actor: @manager, to_status: "confirmed").call.success?
  end

  test "invalid skip and pharmacist operations are denied while cancellation releases" do
    order = normal_order
    assert_not Orders::Transition.new(order:, actor: @manager, to_status: "ready_for_delivery").call.success?
    assert_not Orders::Transition.new(order:, actor: @pharmacist, to_status: "confirmed").call.success?
    assert Orders::Transition.new(order:, actor: @manager, to_status: "cancelled").call.success?
    assert order.reload.cancelled?
    assert order.inventory_reservations.released.exists?
  end

  private

  def normal_order
    create_order(products(:skin_product))
  end

  def prescription_order
    product = products(:featured)
    product.update!(requires_prescription: true)
    file = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/prescription.pdf"), "application/pdf")
    create_order(product, prescription_files: [ file ])
  end

  def create_order(product, prescription_files: [])
    cart = @customer.carts.active.first || @customer.carts.create!(currency: "EGP")
    cart.items.delete_all
    cart.items.create!(product:, quantity: 1)
    cart.ensure_checkout_submission_token!
    result = Orders::CreateFromCart.new(user: @customer, cart:, address_id: addresses(:home).id, delivery_method: "standard", payment_method: "cash_on_delivery", submission_token: cart.checkout_submission_token, prescription_files:).call
    assert result.success?, result.errors.inspect
    result.order
  end
end
