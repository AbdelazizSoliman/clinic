class CreateCarts < ActiveRecord::Migration[7.2]
  def change
    create_table :carts do |t|
      t.references :user, null: true, foreign_key: true
      t.string :guest_token
      t.integer :status, null: false, default: 0
      t.string :currency, null: false, default: "EGP"
      t.datetime :browser_imported_at
      t.timestamps
    end

    add_index :carts, :guest_token, unique: true, where: "guest_token IS NOT NULL"
    add_index :carts, :user_id, unique: true, where: "status = 0 AND user_id IS NOT NULL", name: "index_one_active_cart_per_user"
    add_check_constraint :carts, "status IN (0, 1, 2)", name: "carts_status_valid"
    add_check_constraint :carts, "(user_id IS NOT NULL) <> (guest_token IS NOT NULL)", name: "carts_exactly_one_owner"
  end
end
