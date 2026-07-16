class CreateCartItems < ActiveRecord::Migration[7.2]
  def change
    create_table :cart_items do |t|
      t.references :cart, null: false, foreign_key: { on_delete: :cascade }
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.timestamps
    end

    add_index :cart_items, %i[cart_id product_id], unique: true
    add_check_constraint :cart_items, "quantity > 0", name: "cart_items_quantity_positive"
    add_check_constraint :cart_items, "quantity <= 10", name: "cart_items_quantity_maximum"
  end
end
