require "test_helper"

class PosTest < ActiveSupport::TestCase
  setup do
    @cashier = users(:order_manager)
    @pharmacist = users(:pharmacist)
    @admin = users(:admin)
    @product = products(:featured)
    @product.update!(barcode: "6221234567890", sku: "POS-TEST")
    @session = Pos::OpenSession.new(actor: @cashier, opening_cash_cents: 10_000, identifier: "TEST-SHIFT").call.record
  end

  test "session opening is authorized, nonnegative, and idempotent per cashier" do
    assert @session.open?
    assert_equal 10_000, @session.opening_cash_cents
    assert_equal @session, Pos::OpenSession.new(actor: @cashier, opening_cash_cents: 20_000).call.record
    assert_not Pos::OpenSession.new(actor: users(:customer), opening_cash_cents: 0).call.success?
    assert_not Pos::OpenSession.new(actor: @pharmacist, opening_cash_cents: -1).call.success?
  end

  test "draft cart merges products recalculates totals and has no stock effect" do
    sale = create_sale
    before = @product.reload.stock_quantity
    service = Pos::Cart.new(sale:, actor: @cashier)
    assert service.add(product: @product).success?
    assert service.add(product: @product, quantity: 2).success?
    assert_equal 1, sale.items.count
    assert_equal 3, sale.items.first.quantity
    assert_equal before, @product.reload.stock_quantity
    assert_not service.add(product: products(:inactive)).success?
    assert_not service.update(item: sale.items.first, quantity: 1000).success?
  end

  test "completion consumes FEFO across batches and is idempotent" do
    primary = inventory_batches(:featured_primary)
    primary.update_columns(expiry_date: Date.current + 30.days, on_hand_quantity: 2, original_quantity: 2)
    later = InventoryBatch.create!(product: @product, batch_number: "POS-LATER",
      expiry_date: Date.current + 1.year, received_at: Time.current, original_quantity: 5,
      on_hand_quantity: 5, reserved_quantity: 0, unit_cost_cents: 4100)
    Inventory::BatchAggregate.sync_product!(@product)
    sale = create_sale
    assert Pos::Cart.new(sale:, actor: @cashier).add(product: @product, quantity: 4).success?
    before = @product.reload.stock_quantity

    result = complete(sale, key: "pos-complete-fefo", tendered: sale.total_cents + 500)
    assert result.success?, result.errors.join(", ")
    sale.reload
    assert sale.completed?
    assert_equal 2, sale.items.first.batch_allocations.count
    assert_equal 0, primary.reload.on_hand_quantity
    assert_equal 3, later.reload.on_hand_quantity
    assert_equal before - 4, @product.reload.stock_quantity
    assert_equal 4, sale.items.first.batch_allocations.sum(:quantity)
    assert_equal 2, InventoryMovement.pos_sale.where(reference: sale.items.first).count
    assert_equal 500, sale.payments.first.change_cents

    counts = [ PosSale.count, PosPayment.count, InventoryMovement.count ]
    retry_result = complete(sale, key: "pos-complete-fefo", tendered: sale.total_cents + 500)
    assert retry_result.success?
    assert_equal counts, [ PosSale.count, PosPayment.count, InventoryMovement.count ]
  end

  test "completion rejects insufficient payment and rolls all inventory back" do
    sale = create_sale
    Pos::Cart.new(sale:, actor: @cashier).add(product: @product, quantity: 2)
    batch_before = inventory_batches(:featured_primary).reload.on_hand_quantity
    result = complete(sale, key: "pos-bad-payment", tendered: sale.total_cents - 1)
    assert_not result.success?
    assert sale.reload.draft?
    assert_equal batch_before, inventory_batches(:featured_primary).reload.on_hand_quantity
    assert_empty sale.payments
    assert_empty sale.items.first.batch_allocations
  end

  test "prescription lines require pharmacist approval and cannot reuse another approval" do
    @product.update!(requires_prescription: true)
    sale = create_sale
    Pos::Cart.new(sale:, actor: @cashier).add(product: @product)
    assert_not complete(sale, key: "rx-blocked").success?
    item = sale.items.first
    assert_not Pos::ApprovePrescription.new(item:, actor: @admin, reason: "مدير").call.success?
    approval = Pos::ApprovePrescription.new(item:, actor: @pharmacist, reason: "مراجعة مباشرة في الصيدلية").call
    assert approval.success?
    assert_equal @pharmacist, item.reload.prescription_approved_by
    assert item.prescription_approved_at
    assert complete(sale, key: "rx-approved").success?

    other = create_sale(number: "POS-OTHER")
    Pos::Cart.new(sale: other, actor: @cashier).add(product: @product)
    assert_not complete(other, key: "rx-other").success?
  end

  test "manual discount requires admin approval reason and cannot make total negative" do
    sale = create_sale
    Pos::Cart.new(sale:, actor: @cashier).add(product: @product)
    assert_not Pos::ApproveDiscount.new(sale:, actor: @cashier, amount_cents: 100, reason: "خصم").call.success?
    assert_not Pos::ApproveDiscount.new(sale:, actor: @admin, amount_cents: sale.total_cents + 1, reason: "خصم").call.success?
    assert_not Pos::ApproveDiscount.new(sale:, actor: @admin, amount_cents: 100, reason: "").call.success?
    assert Pos::ApproveDiscount.new(sale:, actor: @admin, amount_cents: 100, reason: "خصم خدمة موثق").call.success?
    assert_equal 100, sale.reload.manual_discount_cents
    assert_equal @admin, sale.discount_approved_by
  end

  test "void is draft only and closing derives expected cash and variance" do
    draft = create_sale
    assert Pos::VoidSale.new(sale: draft, actor: @cashier, reason: "تراجع العميل").call.success?
    assert draft.reload.voided?

    completed = create_sale(number: "POS-CASH")
    Pos::Cart.new(sale: completed, actor: @cashier).add(product: @product)
    assert complete(completed, key: "cash-close").success?
    assert_not Pos::VoidSale.new(sale: completed, actor: @admin, reason: "ممنوع").call.success?
    expected = 10_000 + completed.total_cents
    result = Pos::CloseSession.new(session: @session, actor: @cashier,
      counted_cash_cents: expected + 100, notes: "فرق بسيط", lock_version: @session.lock_version).call
    assert result.success?, result.errors.join(", ")
    assert_equal expected, @session.reload.expected_cash_cents
    assert_equal 100, @session.cash_difference_cents
    assert_not @session.update(notes: "تعديل لاحق")
  end

  test "session close blocks open drafts and large unexplained variance" do
    create_sale
    assert_not Pos::CloseSession.new(session: @session, actor: @cashier, counted_cash_cents: 10_000).call.success?
    @session.pos_sales.draft.first.update!(status: :voided, voided_at: Time.current, voided_by: @cashier, void_reason: "تنظيف")
    assert_not Pos::CloseSession.new(session: @session, actor: @cashier, counted_cash_cents: 9_000).call.success?
  end

  test "expired and quarantined batches are excluded" do
    inventory_batches(:featured_primary).update_columns(expiry_date: Date.yesterday)
    quarantine = InventoryBatch.create!(product: @product, batch_number: "POS-HOLD", expiry_date: 1.year.from_now,
      received_at: Time.current, original_quantity: 5, on_hand_quantity: 5, reserved_quantity: 0,
      quarantined_at: Time.current, quarantined_by: @admin, quarantine_reason: "فحص")
    Inventory::BatchAggregate.sync_product!(@product)
    sale = create_sale
    assert_not Pos::Cart.new(sale:, actor: @cashier).add(product: @product).success?
    assert_equal 5, quarantine.reload.on_hand_quantity
  end

  private

  def create_sale(number: "POS-TEST-#{SecureRandom.hex(3)}")
    @session.pos_sales.create!(cashier: @cashier, number:)
  end

  def complete(sale, key:, tendered: nil)
    tendered ||= sale.total_cents
    Pos::Complete.new(sale:, actor: @cashier, idempotency_key: key,
      payments: [ { payment_method: "cash", amount_cents: sale.total_cents, tendered_cents: tendered } ]).call
  end
end
