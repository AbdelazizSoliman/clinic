require "test_helper"

class PurchasingTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    @inventory = users(:inventory_manager)
    @supplier = Supplier.create!(name: "شركة التوريد", code: "SUP-TEST", email: " SALES@EXAMPLE.TEST ", phone: "010 1234 5678")
    @product = products(:featured)
  end

  test "supplier normalizes stable fields and referenced suppliers cannot be destroyed" do
    assert_equal "sales@example.test", @supplier.email
    assert_equal "01012345678", @supplier.phone
    assert_not Supplier.new(name: "مكرر", code: "sup-test").valid?
    order = create_order
    assert_not @supplier.destroyable?
    assert_not @supplier.destroy
    assert order.persisted?
  end

  test "inventory manager creates draft and snapshots an active product" do
    order = create_order
    result = add_item(order, quantity: 3, cost: 1_250)
    assert result.success?
    assert_equal @product.name, result.item.product_name_snapshot
    assert_equal 3_750, order.reload.total_cents
    assert_equal 0, @product.reload.inventory_movements.purchase_received.count
    assert_not @product.deletable?
  end

  test "duplicate products invalid quantities and inactive products are rejected" do
    order = create_order
    assert add_item(order, quantity: 1, cost: 100).success?
    assert_not add_item(order, quantity: 1, cost: 100).success?
    assert_not Purchasing::AddItem.new(purchase_order: order, actor: @inventory, product: products(:inactive),
      ordered_quantity: 1, unit_cost_cents: 100).call.success?
    assert_not Purchasing::AddItem.new(purchase_order: create_order, actor: @inventory, product: @product,
      ordered_quantity: 0, unit_cost_cents: 100).call.success?
  end

  test "submission freezes lines and only admin can approve" do
    order = create_order
    item = add_item(order, quantity: 2, cost: 700).item
    assert Purchasing::Submit.new(purchase_order: order, actor: @inventory).call.success?
    assert order.reload.submitted?
    assert_not Purchasing::UpdateItem.new(item: item.reload, actor: @inventory, ordered_quantity: 3,
      unit_cost_cents: 700).call.success?
    assert_not Purchasing::Approve.new(purchase_order: order, actor: @inventory).call.success?
    assert Purchasing::Approve.new(purchase_order: order, actor: @admin).call.success?
    assert_equal @admin, order.reload.approved_by
    assert order.approved_at
  end

  test "empty order and inactive supplier cannot be approved" do
    empty = create_order
    assert_not Purchasing::Submit.new(purchase_order: empty, actor: @inventory).call.success?
    order = create_order
    add_item(order, quantity: 1, cost: 100)
    @supplier.update!(active: false)
    assert_not Purchasing::Submit.new(purchase_order: order, actor: @inventory).call.success?
  end

  test "partial and multiple receipts increase stock once and preserve costs" do
    order = approved_order(quantity: 5, cost: 1_200)
    item = order.items.first
    before = @product.reload.stock_quantity
    first = receive(order, item, 2, "receipt-key-1")
    assert first.success?
    assert order.reload.partially_received?
    assert_equal 2, item.reload.received_quantity
    assert_equal before + 2, @product.reload.stock_quantity
    assert_equal 1_200, first.receipt.items.first.unit_cost_cents
    assert_equal 1_200, PurchaseReceiptItem.latest_cost_for(product: @product, supplier: @supplier)
    assert_equal first.receipt, @product.inventory_movements.purchase_received.last.reference

    repeated = receive(order, item, 2, "receipt-key-1")
    assert repeated.success?
    assert_equal first.receipt, repeated.receipt
    assert_equal before + 2, @product.reload.stock_quantity

    second = receive(order.reload, item.reload, 3, "receipt-key-2")
    assert second.success?
    assert order.reload.received?
    assert_equal 5, item.reload.received_quantity
    assert_equal before + 5, @product.reload.stock_quantity
    assert_equal 2, @product.inventory_movements.purchase_received.where(reference_type: "PurchaseReceipt").count
  end

  test "receipt line must match its order product movement and quantity" do
    first_order = approved_order(quantity: 2, cost: 500)
    first_item = first_order.items.first
    receipt = receive(first_order, first_item, 1, "matching-receipt").receipt
    second_order = approved_order(quantity: 1, cost: 600)
    second_item = second_order.items.first

    cross_order = receipt.items.build(purchase_order_item: second_item, inventory_movement: receipt.items.first.inventory_movement,
      quantity: 1, unit_cost_cents: 600)
    assert_not cross_order.valid?
    assert_includes cross_order.errors[:purchase_order_item], "لا ينتمي إلى أمر الشراء الخاص بالإيصال"
    assert cross_order.errors[:inventory_movement_id].any?
  end

  test "same receipt key cannot be reused by another order" do
    first_order = approved_order(quantity: 1, cost: 500)
    assert receive(first_order, first_order.items.first, 1, "shared-receipt-key").success?
    second_order = approved_order(quantity: 1, cost: 600)

    result = receive(second_order, second_order.items.first, 1, "shared-receipt-key")
    assert_not result.success?
    assert_equal 0, second_order.items.first.reload.received_quantity
  end

  test "over receipt and invalid states do not change stock" do
    order = approved_order(quantity: 2, cost: 500)
    item = order.items.first
    before = @product.reload.stock_quantity
    assert_not receive(order, item, 3, "over-receipt").success?
    assert_equal before, @product.reload.stock_quantity
    assert_equal 0, item.reload.received_quantity

    draft = create_order
    draft_item = add_item(draft, quantity: 2, cost: 500).item
    assert_not receive(draft, draft_item, 1, "draft-receipt").success?
  end

  test "invalid receiving rolls back receipt line and stock" do
    order = approved_order(quantity: 2, cost: 500)
    item = order.items.first
    before = @product.reload.stock_quantity
    result = Purchasing::Receive.new(purchase_order: order, actor: @inventory,
      quantities: { item.id.to_s => 1, "999999" => 1 }, idempotency_key: "invalid-line").call
    assert_not result.success?
    assert_equal before, @product.reload.stock_quantity
    assert_equal 0, item.reload.received_quantity
    assert_equal 0, order.receipts.count
  end

  test "cancellation preserves posted stock and blocks future receipts" do
    order = approved_order(quantity: 4, cost: 900)
    item = order.items.first
    assert receive(order, item, 1, "partial-before-cancel").success?
    stock = @product.reload.stock_quantity
    assert Purchasing::Cancel.new(purchase_order: order.reload, actor: @inventory, reason: "توقف التوريد").call.success?
    assert order.reload.cancelled?
    assert_equal 1, item.reload.received_quantity
    assert_equal stock, @product.reload.stock_quantity
    assert_not receive(order, item, 1, "after-cancel").success?
  end

  test "received orders close and historical snapshots survive deactivation" do
    order = approved_order(quantity: 1, cost: 777)
    item = order.items.first
    assert receive(order, item, 1, "full-receipt").success?
    original_name = item.product_name_snapshot
    @product.reload.update!(active: false, name: "اسم جديد")
    @supplier.update!(active: false)
    assert_equal original_name, item.reload.product_name_snapshot
    assert_equal 777, item.unit_cost_cents
    assert Purchasing::Close.new(purchase_order: order.reload, actor: @inventory).call.success?
    assert order.reload.closed?
    assert_not receive(order, item, 1, "closed-receipt").success?
  end

  test "customers and pharmacists cannot operate purchasing" do
    [ users(:customer), users(:pharmacist), users(:order_manager) ].each do |actor|
      result = Purchasing::CreateOrder.new(actor:, supplier: @supplier).call
      assert_not result.success?
    end
  end

  private

  def create_order
    Purchasing::CreateOrder.new(actor: @inventory, supplier: @supplier,
      attributes: { expected_at: Date.current + 5.days }).call.purchase_order
  end

  def add_item(order, quantity:, cost:)
    Purchasing::AddItem.new(purchase_order: order, actor: @inventory, product: @product,
      ordered_quantity: quantity, unit_cost_cents: cost).call
  end

  def approved_order(quantity:, cost:)
    order = create_order
    add_item(order, quantity:, cost:)
    Purchasing::Submit.new(purchase_order: order, actor: @inventory).call
    Purchasing::Approve.new(purchase_order: order.reload, actor: @admin).call
    order.reload
  end

  def receive(order, item, quantity, key)
    Purchasing::Receive.new(purchase_order: order, actor: @inventory,
      quantities: { item.id.to_s => quantity }, idempotency_key: key).call
  end
end
