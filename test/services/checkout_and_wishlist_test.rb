require "test_helper"

class CheckoutAndWishlistTest < ActiveSupport::TestCase
  test "wishlist import accepts unique active ids only and is idempotent" do
    user = users(:customer)
    service = -> { Wishlists::ImportBrowserWishlist.new(user:, product_ids: [ products(:skin_product).id, products(:skin_product).id, products(:inactive).id, "bad" ]).call }
    assert_equal 1, service.call
    assert_equal 0, service.call
    assert user.wishlist_items.exists?(product: products(:skin_product))
    assert_not user.wishlist_items.exists?(product: products(:inactive))
  end

  test "readiness reports supported address and prescription state" do
    result = Checkout::Readiness.new(user: users(:customer), cart: carts(:customer_cart), address: addresses(:home)).call
    assert result.ready
    assert_not result.prescription_required
  end

  test "readiness rejects foreign inactive unsupported address and stock issues" do
    result = Checkout::Readiness.new(user: users(:customer), cart: carts(:customer_cart), address: addresses(:other_home)).call
    assert_not result.ready
    assert_includes result.errors, "اختر عنوان توصيل نشطًا من حسابك"
  end
end
