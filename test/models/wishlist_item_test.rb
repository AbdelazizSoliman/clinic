require "test_helper"

class WishlistItemTest < ActiveSupport::TestCase
  test "belongs to user and product and is unique" do
    duplicate = WishlistItem.new(user: users(:customer), product: products(:featured))
    assert_not duplicate.valid?
    assert_equal users(:customer), wishlist_items(:customer_featured).user
  end

  test "does not add inactive product" do
    assert_not WishlistItem.new(user: users(:customer), product: products(:inactive)).valid?
  end

  test "database uniqueness is enforced" do
    assert_raises ActiveRecord::RecordNotUnique do
      WishlistItem.insert_all!([ { user_id: users(:customer).id, product_id: products(:featured).id, created_at: Time.current, updated_at: Time.current } ])
    end
  end
end
