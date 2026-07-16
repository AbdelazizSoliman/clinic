require "test_helper"

class OrderAndInventoryTest < ActiveSupport::TestCase
  setup do
    @user = users(:admin)
    @cart = @user.carts.create!(currency: "EGP", checkout_submission_token: SecureRandom.urlsafe_base64(32))
    @cart.items.create!(product: products(:skin_product), quantity: 2)
    @address = @user.addresses.create!(label: "المنزل", recipient_name: @user.full_name, mobile_number: @user.mobile_number, governorate: "القاهرة", city: "المعادي", street: "شارع 9", building_number: "4", default: true, active: true)
  end

  test "normal order persists immutable item and address snapshots and reservation" do
    result = create_order
    assert result.success?, result.errors.inspect
    order = result.order
    assert order.submitted?
    assert order.unpaid?
    assert_match(/\APH-\d{8}-[A-Z0-9]{6}\z/, order.number)
    assert_equal 50_000, order.total_cents
    assert_equal "كريم مرطب", order.items.first.product_name
    assert_equal 2, order.inventory_reservations.active.first.quantity

    @address.update!(street: "شارع آخر")
    products(:skin_product).update!(name: "اسم جديد", price: 300)
    assert_equal "شارع 9", order.order_address.reload.street
    assert_equal "كريم مرطب", order.items.first.reload.product_name
    assert_equal 25_000, order.items.first.unit_price_cents
    assert @cart.reload.completed?
  end

  test "available to sell reflects release and consumption semantics" do
    order = create_order.order
    product = products(:skin_product)
    assert_equal 3, product.available_to_sell_quantity
    assert Inventory::ReleaseReservations.new(order).call
    assert Inventory::ReleaseReservations.new(order).call
    assert_equal 5, product.available_to_sell_quantity

    reservation = order.inventory_reservations.first
    reservation.update!(status: :active, released_at: nil)
    assert Inventory::ConsumeReservations.new(order).call
    assert_equal 3, product.reload.stock_quantity
    assert_not Inventory::ConsumeReservations.new(order).call
  end

  test "model monetary and database constraints reject invalid values" do
    order = create_order.order
    item = order.items.first
    item.line_total_cents = 1
    assert_not item.valid?
    assert_raises ActiveRecord::StatementInvalid do
      InventoryReservation.where(id: order.inventory_reservations.first.id).update_all(quantity: 0)
    end
  end

  private

  def create_order(**overrides)
    Orders::CreateFromCart.new(**{
      user: @user, cart: @cart, address_id: @address.id, delivery_method: "standard",
      payment_method: "cash_on_delivery", submission_token: @cart.checkout_submission_token
    }.merge(overrides)).call
  end
end
