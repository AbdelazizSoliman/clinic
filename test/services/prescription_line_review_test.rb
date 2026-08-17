require "test_helper"

class PrescriptionLineReviewTest < ActiveSupport::TestCase
  setup do
    @pharmacist = users(:pharmacist)
    @admin = users(:admin)
    @manager = users(:order_manager)
    @inventory_manager = users(:inventory_manager)
    @customer = users(:customer)
    @original = products(:featured)
    @substitute = products(:skin_product)
    @original.update!(requires_prescription: true)
    @substitute.update!(requires_prescription: true)
  end

  test "ensure review creates one item per prescription line and skips ordinary lines" do
    order = build_order(rx: [ @original ], ordinary: [ products(:skin_product).tap { |p| p.update!(requires_prescription: false) } ])
    review = Prescriptions::EnsureReview.call(order.prescription)
    assert_equal 1, review.items.count
    assert_equal @original, review.items.first.original_product
    assert_equal 1, PrescriptionReview.where(reviewable: order.prescription).count

    assert_equal review, Prescriptions::EnsureReview.call(order.prescription)
    assert_equal 1, review.items.count
  end

  test "start line review requires pharmacist and blocks invalid transitions" do
    order = build_order(rx: [ @original ])
    item = review_item_for(order)

    assert_not Prescriptions::StartLineReview.new(item:, actor: @customer).call.success?
    assert_not Prescriptions::StartLineReview.new(item:, actor: @admin).call.success?

    result = Prescriptions::StartLineReview.new(item:, actor: @pharmacist).call
    assert result.success?
    assert item.reload.under_review?
    assert item.prescription_review.reload.under_review?
    assert order.prescription.reload.under_review?

    decide!(item, "approved")
    assert_not Prescriptions::StartLineReview.new(item: item.reload, actor: @pharmacist).call.success?
  end

  test "approval requires reason, dispenses original product, and allocates inventory" do
    order = build_order(rx: [ @original ])
    item = review_item_for(order)

    assert_not Prescriptions::DecideLine.new(item:, actor: @pharmacist, decision: "approved", reason: "").call.success?
    assert_not Prescriptions::DecideLine.new(item:, actor: @manager, decision: "approved", reason: "تفويض غير صحيح").call.success?

    result = decide!(item, "approved")
    assert result.success?
    item.reload
    assert item.approved?
    assert_equal @original, item.dispensed_product
    assert item.dispensable?
    reservation = order.items.first.inventory_reservation
    assert reservation.active?
    assert_equal @original, reservation.product
    assert reservation.reservation_allocations.exists?
  end

  test "terminal decision cannot be silently overwritten" do
    order = build_order(rx: [ @original ])
    item = review_item_for(order)
    decide!(item, "approved")

    again = Prescriptions::DecideLine.new(item: item.reload, actor: @pharmacist, decision: "rejected", reason: "محاولة تغيير").call
    assert_not again.success?
    assert_includes again.errors.join, "تم اتخاذ قرار نهائي"
    assert item.reload.approved?

    assert_raises(ActiveRecord::RecordInvalid) { item.update!(status: :rejected) }
  end

  test "stale lock version is rejected" do
    order = build_order(rx: [ @original ])
    item = review_item_for(order)
    result = Prescriptions::DecideLine.new(item:, actor: @pharmacist, decision: "approved",
      reason: "اعتماد", lock_version: item.lock_version + 1).call
    assert_not result.success?
    assert_includes result.errors.join, "أعد تحميل"
  end

  test "rejection releases reservation and leaves other lines untouched" do
    ordinary = products(:skin_product)
    ordinary.update!(requires_prescription: false)
    order = build_order(rx: [ @original ], ordinary: [ ordinary ])
    item = review_item_for(order)

    result = decide!(item, "rejected")
    assert result.success?
    item.reload
    assert item.rejected?
    assert_nil item.dispensed_product
    assert_not order.items.find_by(product: @original).inventory_reservation&.active?

    ordinary_item = order.items.find_by(product: ordinary)
    assert ordinary_item.inventory_reservation.active?
  end

  test "substitution validates the candidate product" do
    order = build_order(rx: [ @original ])
    item = review_item_for(order)

    inactive_substitute = Product.create!(name: "بديل غير نشط", slug: "inactive-sub-#{SecureRandom.hex(3)}",
      price: 50, requires_prescription: true, active: false, category: @original.category, brand: @original.brand)
    assert_not Prescriptions::DecideLine.new(item:, actor: @pharmacist, decision: "substituted",
      reason: "بديل", substitute_product: inactive_substitute).call.success?

    non_rx_substitute = Product.create!(name: "بديل غير موصوف", slug: "non-rx-sub-#{SecureRandom.hex(3)}",
      price: 50, requires_prescription: false, active: true, category: @original.category, brand: @original.brand)
    assert_not Prescriptions::DecideLine.new(item:, actor: @pharmacist, decision: "substituted",
      reason: "بديل", substitute_product: non_rx_substitute).call.success?

    assert_not Prescriptions::DecideLine.new(item:, actor: @pharmacist, decision: "substituted",
      reason: "بديل", substitute_product: @original).call.success?

    unavailable_substitute = Product.create!(name: "بديل بدون مخزون", slug: "no-stock-sub-#{SecureRandom.hex(3)}",
      price: 50, requires_prescription: true, active: true, category: @original.category, brand: @original.brand)
    assert_not Prescriptions::DecideLine.new(item:, actor: @pharmacist, decision: "substituted",
      reason: "بديل", substitute_product: unavailable_substitute).call.success?
  end

  test "substitution preserves original product, allocates the substitute, and is traceable" do
    order = build_order(rx: [ @original ])
    item = review_item_for(order)

    result = Prescriptions::DecideLine.new(item:, actor: @pharmacist, decision: "substituted",
      reason: "بديل علاجي متاح", substitute_product: @substitute).call
    assert result.success?, result.errors.join(", ")
    item.reload
    assert item.substituted?
    assert_equal @original, item.original_product
    assert_equal @substitute, item.dispensed_product
    assert_equal @original, item.therapeutic_substitution.original_product
    assert_equal @substitute, item.therapeutic_substitution.substitute_product
    assert_equal @pharmacist, item.therapeutic_substitution.pharmacist

    reservation = order.items.first.inventory_reservation
    assert reservation.active?
    assert_equal @substitute, reservation.product
    assert reservation.inventory_batches.all? { |batch| batch.product_id == @substitute.id }

    decision = item.decisions.order(:created_at).last
    assert_equal "substituted", decision.to_status
    assert_equal @pharmacist, decision.actor
  end

  test "mixed order keeps ordinary approved and rejected lines internally consistent" do
    other_rx = products_with_batch("MIXED-RX-B", price: 60)
    ordinary = products(:skin_product)
    ordinary.update!(requires_prescription: false)
    order = build_order(rx: [ @original, other_rx ], ordinary: [ ordinary ])

    approve_item = order.prescription.prescription_review.items.find_by!(original_product: @original)
    reject_item = order.prescription.prescription_review.items.find_by!(original_product: other_rx)
    assert decide!(approve_item, "approved").success?
    assert decide!(reject_item, "rejected").success?

    order.reload
    assert order.submitted?
    assert order.prescription.reload.partially_approved?
    assert order.items.find_by(product: ordinary).inventory_reservation.active?
    assert order.items.find_by(product: @original).inventory_reservation.active?
    assert_not order.items.find_by(product: other_rx).inventory_reservation&.active?
    expected_total = order.subtotal_cents - order.discount_cents + order.delivery_fee_cents -
      order.delivery_discount_cents + order.prescription_adjustment_cents
    assert_equal expected_total, order.total_cents
  end

  test "audit events are recorded for line review actions" do
    order = build_order(rx: [ @original ])
    item = review_item_for(order)
    Prescriptions::StartLineReview.new(item:, actor: @pharmacist).call
    decide!(item.reload, "approved")

    assert AdminAuditEvent.exists?(action: "prescription_line_review_started", auditable: item.prescription_review)
    assert AdminAuditEvent.exists?(action: "prescription_line_approved", auditable: item.prescription_review)
  end

  private

  def decide!(item, decision, substitute_product: nil)
    Prescriptions::DecideLine.new(item:, actor: @pharmacist, decision:, reason: "قرار سريري موثق للاختبار",
      substitute_product:).call
  end

  def review_item_for(order)
    Prescriptions::EnsureReview.call(order.prescription).items.first
  end

  def products_with_batch(batch_number, price:)
    product = Product.create!(name: "منتج روشتة #{batch_number}", slug: "rx-#{batch_number.downcase}-#{SecureRandom.hex(3)}",
      price:, requires_prescription: true, active: true, category: @original.category, brand: @original.brand)
    product.inventory_batches.create!(batch_number:, lot_number: "LOT-#{batch_number}", expiry_date: 1.year.from_now,
      received_at: Time.current, original_quantity: 10, on_hand_quantity: 10, reserved_quantity: 0, unit_cost_cents: 3000)
    Inventory::BatchAggregate.sync_product!(product)
    product
  end

  def build_order(rx:, ordinary: [])
    cart = @customer.carts.active.first || @customer.carts.create!(currency: "EGP")
    cart.items.delete_all
    (rx + ordinary).each { |product| cart.items.create!(product:, quantity: 1) }
    cart.ensure_checkout_submission_token!
    file = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/prescription.pdf"), "application/pdf")
    result = Orders::CreateFromCart.new(user: @customer, cart:, address_id: addresses(:home).id,
      delivery_method: "standard", payment_method: "cash_on_delivery",
      submission_token: cart.checkout_submission_token, prescription_files: [ file ]).call
    assert result.success?, result.errors.inspect
    result.order
  end
end
