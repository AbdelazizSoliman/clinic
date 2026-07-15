class CreateProducts < ActiveRecord::Migration[7.2]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :short_description
      t.text :description
      t.decimal :price, precision: 10, scale: 2, null: false
      t.decimal :compare_at_price, precision: 10, scale: 2
      t.integer :stock_quantity, null: false, default: 0
      t.boolean :featured, null: false, default: false
      t.boolean :requires_prescription, null: false, default: false
      t.boolean :active, null: false, default: true
      t.references :category, null: false, foreign_key: true
      t.references :brand, null: false, foreign_key: true
      t.timestamps
    end

    add_index :products, :slug, unique: true
    add_index :products, :featured
    add_index :products, :active
    add_check_constraint :products, "price >= 0", name: "products_price_non_negative"
    add_check_constraint :products, "compare_at_price IS NULL OR compare_at_price >= 0", name: "products_compare_at_price_non_negative"
    add_check_constraint :products, "stock_quantity >= 0", name: "products_stock_quantity_non_negative"
  end
end
