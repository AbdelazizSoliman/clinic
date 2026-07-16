require "test_helper"

class OrdersCreateFromCartTest < ActiveSupport::TestCase
  setup do
    @user = users(:admin)
    @address = @user.addresses.create!(label: "المنزل", recipient_name: @user.full_name, mobile_number: @user.mobile_number, governorate: "القاهرة", city: "الشروق", street: "الحرية", building_number: "1", default: true, active: true)
  end

  test "prescription order requires valid attachment and rolls back fully when missing" do
    product = products(:featured)
    product.update!(requires_prescription: true)
    cart = cart_with(product, 1)
    result = call_service(cart)
    assert_not result.success?
    assert_includes result.errors, "يجب إرفاق صورة أو ملف روشتة"
    assert_equal 0, Order.where(cart:).count
    assert_equal 0, InventoryReservation.joins(:order).where(orders: { cart_id: cart.id }).count
    assert cart.reload.active?

    file = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/prescription.pdf"), "application/pdf")
    result = call_service(cart, prescription_files: [ file ])
    assert result.success?, result.errors.inspect
    assert result.order.pending_prescription?
    assert result.order.prescription.submitted?
    assert_equal 1, result.order.prescription.images.count
  end

  test "rejects invalid files and unsupported or foreign selections" do
    product = products(:featured)
    product.update!(requires_prescription: true)
    cart = cart_with(product, 1)
    bad = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/prescription.pdf"), "text/plain")
    assert_not call_service(cart, prescription_files: [ bad ]).success?
    assert_not call_service(cart, address_id: addresses(:other_home).id).success?
    assert_not call_service(cart, payment_method: "card_placeholder").success?
    @address.update!(governorate: "الإسكندرية")
    assert_not call_service(cart).success?
  end

  test "rejects empty inactive and insufficient carts without completion" do
    empty = cart_with(nil, nil)
    assert_not call_service(empty).success?
    empty.update!(status: :abandoned)
    product = products(:skin_product)
    cart = cart_with(product, 6)
    assert_not call_service(cart).success?
    product.update!(active: false)
    cart.items.first.update!(quantity: 1)
    assert_not call_service(cart).success?
    assert cart.reload.active?
  end

  test "submission is idempotent and current database price wins" do
    product = products(:skin_product)
    product.update!(price: 275)
    cart = cart_with(product, 1)
    first = call_service(cart)
    second = call_service(cart)
    assert first.success?
    assert second.success?
    assert_equal first.order, second.order
    assert_equal 1, Order.where(cart:).count
    assert_equal 27_500, first.order.items.first.unit_price_cents
  end

  test "active reservations prevent a competing cart from taking the same stock" do
    product = products(:skin_product)
    product.update!(stock_quantity: 5)
    first_cart = cart_with(product, 4)
    assert call_service(first_cart).success?
    second_cart = cart_with(product, 2)
    result = call_service(second_cart)
    assert_not result.success?
    assert_includes result.errors.join, "المتاح 1"
  end

  private

  def cart_with(product, quantity)
    cart = @user.carts.create!(currency: "EGP", checkout_submission_token: SecureRandom.urlsafe_base64(32))
    cart.items.create!(product:, quantity:) if product
    cart
  end

  def call_service(cart, **overrides)
    Orders::CreateFromCart.new(**{
      user: @user, cart:, address_id: @address.id, delivery_method: "standard",
      payment_method: "cash_on_delivery", submission_token: cart.checkout_submission_token
    }.merge(overrides)).call
  end
end
