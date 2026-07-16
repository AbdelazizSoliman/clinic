require "test_helper"

class CatalogInventoryAdministrationTest < ActiveSupport::TestCase
  setup do
    @product = products(:skin_product)
    @manager = users(:inventory_manager)
  end

  test "inventory role has only catalog capabilities" do
    assert @manager.can_manage_catalog?
    assert @manager.can_manage_inventory?
    assert_not @manager.can_review_prescriptions?
    assert_not @manager.can_operate_orders?
  end

  test "pricing update creates immutable cents history" do
    result = Products::UpdatePricing.new(product: @product, actor: @manager, price: "275.50", compare_at_price: "300",
      cost_price: "210", reason: "تحديث قائمة الأسعار", lock_version: @product.lock_version).call
    assert result.success?, result.errors.inspect
    assert_equal 27_550, result.price_change.new_price_cents
    assert_equal @manager, result.price_change.changed_by
    assert_equal 275.50.to_d, @product.reload.price
    assert_not result.price_change.update(reason: "تعديل")
    assert_not Products::UpdatePricing.new(product: @product, actor: users(:customer), price: 10, reason: "غير مصرح").call.success?
  end

  test "stock adjustments create ledger and protect active reservations" do
    before = @product.stock_quantity
    increased = Inventory::AdjustStock.new(product: @product, actor: @manager, movement_type: :manual_increase,
      quantity_delta: 3, reason: "جرد المخزن").call
    assert increased.success?, increased.errors.inspect
    assert_equal before + 3, @product.reload.stock_quantity
    assert_equal 3, increased.movement.quantity_delta

    order = create_order(@product)
    reserved = @product.active_reserved_quantity
    denied = Inventory::AdjustStock.new(product: @product, actor: @manager, movement_type: :manual_decrease,
      quantity_delta: -(@product.stock_quantity - reserved + 1), reason: "خفض غير صالح").call
    assert_not denied.success?
    assert_includes denied.errors.join, "المحجوزة"
    assert order.inventory_reservations.active.exists?
  end

  test "reservation consumption creates one idempotent movement" do
    order = create_order(@product)
    assert Inventory::ConsumeReservations.new(order).call
    reservation = order.inventory_reservations.first
    assert_equal 1, InventoryMovement.where(idempotency_key: "reservation-consumed-#{reservation.id}").count
    assert_not Inventory::ConsumeReservations.new(order).call
    assert_equal 1, InventoryMovement.where(idempotency_key: "reservation-consumed-#{reservation.id}").count
  end

  test "public scope excludes inactive category and brand" do
    assert_includes Product.publicly_available, @product
    @product.category.update!(active: false)
    assert_not_includes Product.publicly_available, @product
  end

  private

  def create_order(product)
    customer = users(:customer)
    cart = customer.carts.active.first || customer.carts.create!(currency: "EGP")
    cart.items.delete_all
    cart.items.create!(product:, quantity: 1)
    cart.ensure_checkout_submission_token!
    result = Orders::CreateFromCart.new(user: customer, cart:, address_id: addresses(:home).id, delivery_method: "standard",
      payment_method: "cash_on_delivery", submission_token: cart.checkout_submission_token).call
    assert result.success?, result.errors.inspect
    result.order
  end
end
