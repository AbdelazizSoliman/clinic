module Wishlists
  class ImportBrowserWishlist
    def initialize(user:, product_ids:)
      @user = user
      @product_ids = Array(product_ids)
    end

    def call
      ids = @product_ids.filter_map { |id| Integer(id, exception: false) }.uniq
      valid_ids = Product.active.where(id: ids).pluck(:id)
      existing_ids = @user.wishlist_items.where(product_id: valid_ids).pluck(:product_id)
      now = Time.current
      rows = (valid_ids - existing_ids).map { |id| { user_id: @user.id, product_id: id, created_at: now, updated_at: now } }
      WishlistItem.insert_all(rows, unique_by: %i[user_id product_id]) if rows.any?
      rows.length
    end
  end
end
