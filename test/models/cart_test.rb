require "test_helper"

class CartTest < ActiveSupport::TestCase
  test "has exactly one owner" do
    assert_not Cart.new(currency: "EGP").valid?
    assert_not Cart.new(user: users(:customer), guest_token: "both", currency: "EGP").valid?
  end

  test "uses EGP and calculates trusted totals" do
    cart = carts(:customer_cart)
    assert_equal "EGP", cart.currency
    assert_equal 2, cart.total_quantity
    assert_equal (products(:featured).price * 100).round * 2, cart.subtotal_cents
  end

  test "detects prescription products" do
    product = products(:featured)
    product.update!(requires_prescription: true)
    assert carts(:customer_cart).requires_prescription?
  end
end
