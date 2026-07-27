require "test_helper"

class BatchInventoryTest < ActiveSupport::TestCase
  setup do
    @manager = users(:inventory_manager)
    @admin = users(:admin)
    @product = Product.create!(name: "منتج تشغيلات", slug: "batch-product", price: 50,
      stock_quantity: 0, category: categories(:medicines), brand: brands(:eva),
      maximum_order_quantity: 20)
  end

  test "batch identity quantities lifecycle and database constraints" do
    batch = create_batch("BATCH-ID", 5, Date.current + 1.year, manufacture_date: Date.current - 1.month)
    assert_equal 5, batch.available_quantity
    assert_equal "available", batch.lifecycle_status
    batch.batch_number = "CHANGED"
    assert_not batch.valid?
    assert_raises ActiveRecord::StatementInvalid do
      InventoryBatch.where(id: batch.id).update_all(reserved_quantity: 6)
    end
  end

  test "FEFO allocates across batches and excludes expired and quarantined stock" do
    expired = create_batch("B-EXPIRED", 10, Date.yesterday)
    early = create_batch("B-EARLY", 2, Date.current + 2.months)
    later = create_batch("B-LATER", 4, Date.current + 8.months)
    quarantined = create_batch("B-HOLD", 10, Date.current + 1.month)
    assert Inventory::ChangeQuarantine.new(batch: quarantined, actor: @manager, quarantined: true, reason: "فحص جودة").call.success?
    reservation = build_reservation(5)

    result = Inventory::AllocateFefo.new(reservation:).call
    assert result.success?, result.errors.inspect
    assert_equal [ [ early.id, 2 ], [ later.id, 3 ] ],
      result.allocations.map { |allocation| [ allocation.inventory_batch_id, allocation.quantity ] }
    assert_equal 0, expired.reload.reserved_quantity
    assert_equal 0, quarantined.reload.reserved_quantity
  end

  test "consumption is batch traced and keeps product aggregate consistent" do
    first = create_batch("B-CONSUME-1", 2, Date.current + 2.months)
    second = create_batch("B-CONSUME-2", 3, Date.current + 3.months)
    reservation = build_reservation(4)
    assert Inventory::AllocateFefo.new(reservation:).call.success?

    assert Inventory::ConsumeReservations.new(reservation.order).call
    assert_equal 0, first.reload.on_hand_quantity
    assert_equal 1, second.reload.on_hand_quantity
    assert_equal 1, @product.reload.stock_quantity
    assert Inventory::BatchAggregate.consistent?(@product)
    assert_equal 2, InventoryMovement.reservation_consumed.where(reference_type: "InventoryReservationAllocation").count
  end

  test "quarantine and adjustments protect reservations and append history" do
    batch = create_batch("B-ADJUST", 5, Date.current + 1.year)
    reservation = build_reservation(2)
    Inventory::AllocateFefo.new(reservation:).call
    assert_not Inventory::ChangeQuarantine.new(batch:, actor: @manager, quarantined: true, reason: "فحص").call.success?
    result = Inventory::AdjustBatch.new(batch:, actor: @manager, movement_type: :damaged,
      quantity_delta: -2, reason: "عبوة تالفة").call
    assert result.success?
    assert_equal 3, batch.reload.on_hand_quantity
    assert_equal batch, result.movement.inventory_batch
    assert_equal 1, batch.events.where(event_type: "adjusted").count
    assert AdminAuditEvent.exists?(auditable: batch, action: "inventory_batch_adjusted")
  end

  test "batch report and CSV expose expiry and valuation" do
    create_batch("B-REPORT-EXPIRED", 2, Date.yesterday, unit_cost_cents: 300)
    create_batch("B-REPORT-NEAR", 3, Date.current + 10.days, unit_cost_cents: 400)
    range = Reports::DateRange.call({ preset: "last_30_days" })
    report = Reports::BatchInventorySummary.new(range, threshold_days: 30).call
    assert_operator report.cards[:expired], :>=, 2
    assert_operator report.cards[:near_expiry], :>=, 3
    assert_operator report.valuation_cents, :>=, 1_800
    csv = Reports::ExportRows.call("batches", range)
    assert_includes csv.rows.map(&:first), "B-REPORT-NEAR"
  end

  test "purchase receiving creates explicit batches once" do
    supplier = Supplier.create!(name: "مورد التشغيلات", code: "BATCH-SUP")
    order = Purchasing::CreateOrder.new(actor: @manager, supplier:).call.purchase_order
    item = Purchasing::AddItem.new(purchase_order: order, actor: @manager, product: @product,
      ordered_quantity: 5, unit_cost_cents: 700).call.item
    Purchasing::Submit.new(purchase_order: order, actor: @manager).call
    Purchasing::Approve.new(purchase_order: order.reload, actor: @admin).call
    attributes = {
      purchase_order: order.reload, actor: @manager, quantities: { item.id => 5 },
      batches: { item.id => [
        { batch_number: "B-RECEIVE-A", expiry_date: Date.current + 3.months, quantity: 2 },
        { batch_number: "B-RECEIVE-B", expiry_date: Date.current + 6.months, quantity: 3 }
      ] }, idempotency_key: "batch-receive-once"
    }
    result = Purchasing::Receive.new(**attributes).call
    assert result.success?, result.errors.inspect
    assert_equal 2, result.receipt.inventory_batches.count
    assert_equal 5, result.receipt.inventory_batches.sum(:on_hand_quantity)
    assert_equal 2, result.receipt.inventory_batches.joins(:inventory_movements).distinct.count
    assert Purchasing::Receive.new(**attributes).call.success?
    assert_equal 2, result.receipt.inventory_batches.count
  end

  private

  def create_batch(number, quantity, expiry, **attributes)
    batch = @product.inventory_batches.create!({
      batch_number: number, expiry_date: expiry, received_at: Time.current,
      original_quantity: quantity, on_hand_quantity: quantity, reserved_quantity: 0
    }.merge(attributes))
    Inventory::BatchAggregate.sync_product!(@product)
    batch
  end

  def build_reservation(quantity)
    cart = @admin.carts.create!(currency: "EGP", checkout_submission_token: SecureRandom.hex(16), status: :completed)
    order = @admin.orders.create!(cart:, number: "BATCH-ORDER-#{SecureRandom.hex(4)}", status: :submitted,
      payment_method: :cash_on_delivery, payment_status: :unpaid, delivery_method: :standard, currency: "EGP",
      subtotal_cents: 5_000, discount_cents: 0, product_discount_cents: 0, cart_discount_cents: 0,
      delivery_discount_cents: 0, delivery_fee_cents: 0, total_cents: 5_000,
      customer_email: @admin.email, customer_mobile_number: @admin.mobile_number,
      customer_first_name: @admin.first_name, customer_last_name: @admin.last_name, submitted_at: Time.current)
    item = order.items.create!(product: @product, product_name: @product.name, product_slug: @product.slug,
      brand_name: @product.brand.name, category_name: @product.category.name, quantity:,
      unit_price_cents: 1_000, original_unit_price_cents: 1_000, final_unit_price_cents: 1_000,
      discount_cents: 0, line_total_cents: quantity * 1_000)
    order.inventory_reservations.create!(order_item: item, product: @product, quantity:, status: :active,
      expires_at: 1.hour.from_now)
  end
end
