require "test_helper"

class Carts::ServicesTest < ActiveSupport::TestCase
  test "set item quantity enforces stock and maximum" do
    product = products(:skin_product)
    product.update!(stock_quantity: 4)
    result = Carts::SetItemQuantity.new(cart: carts(:guest_cart), product:, quantity: 99).call
    assert result.success?
    assert_equal 4, result.item.quantity
  end

  test "set item rejects inactive unavailable and malformed requests" do
    assert_not Carts::SetItemQuantity.new(cart: carts(:guest_cart), product: products(:inactive), quantity: 1).call.success?
    assert_not Carts::SetItemQuantity.new(cart: carts(:guest_cart), product: products(:featured), quantity: "bad").call.success?
  end

  test "merge combines duplicate quantities transactionally and closes guest" do
    session = { guest_cart_token: carts(:guest_cart).guest_token }
    count = Carts::MergeGuestCart.new(session:, user: users(:customer)).call
    assert_equal 1, count
    assert_equal 5, cart_items(:customer_item).reload.quantity
    assert carts(:guest_cart).reload.merged?
    assert_nil session[:guest_cart_token]
  end

  test "merge handles no guest and does not repeat" do
    assert_equal 0, Carts::MergeGuestCart.new(session: {}, user: users(:customer)).call
    session = { guest_cart_token: carts(:guest_cart).guest_token }
    service = Carts::MergeGuestCart.new(session:, user: users(:customer))
    assert_equal 1, service.call
    assert_equal 0, service.call
  end

  test "browser import combines duplicates ignores unknown and is idempotent" do
    cart = carts(:guest_cart)
    payload = [ { productId: products(:skin_product).id, quantity: 2 }, { productId: products(:skin_product).id, quantity: 3 }, { productId: 999_999, quantity: 5 }, { nonsense: true } ]
    assert_equal :imported, Carts::ImportBrowserCart.new(cart:, items: payload).call
    assert_equal 5, cart.items.find_by(product: products(:skin_product)).quantity
    assert_equal :already_imported, Carts::ImportBrowserCart.new(cart:, items: payload).call
  end
end
