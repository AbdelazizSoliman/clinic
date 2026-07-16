class CreateWishlistItems < ActiveRecord::Migration[7.2]
  def change
    create_table :wishlist_items do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :product, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end

    add_index :wishlist_items, %i[user_id product_id], unique: true
  end
end
