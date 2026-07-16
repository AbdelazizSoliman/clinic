require "test_helper"

class CartItemTest < ActiveSupport::TestCase
  test "validates quantity and uniqueness" do
    item = cart_items(:customer_item)
    assert_not CartItem.new(cart: item.cart, product: item.product, quantity: 1).valid?
    item.quantity = 0
    assert_not item.valid?
    item.quantity = 11
    assert_not item.valid?
  end

  test "calculates subtotal from current database price" do
    item = cart_items(:customer_item)
    assert_equal (item.product.price * 100).round * item.quantity, item.subtotal_cents
  end

  test "database rejects invalid quantities" do
    assert_raises(ActiveRecord::StatementInvalid) do
      CartItem.insert_all!([ { cart_id: carts(:guest_cart).id, product_id: products(:skin_product).id, quantity: 0, created_at: Time.current, updated_at: Time.current } ])
    end
  end
end
