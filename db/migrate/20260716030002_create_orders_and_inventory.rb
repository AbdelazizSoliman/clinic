class CreateOrdersAndInventory < ActiveRecord::Migration[7.2]
  def change
    add_column :carts, :checkout_submission_token, :string
    add_index :carts, :checkout_submission_token, unique: true

    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.references :cart, null: false, foreign_key: true, index: { unique: true }
      t.string :number, null: false
      t.integer :status, null: false
      t.integer :payment_method, null: false
      t.integer :payment_status, null: false, default: 0
      t.string :currency, null: false, default: "EGP"
      t.integer :subtotal_cents, null: false, default: 0
      t.integer :discount_cents, null: false, default: 0
      t.integer :delivery_fee_cents, null: false, default: 0
      t.integer :total_cents, null: false, default: 0
      t.string :customer_email, null: false
      t.string :customer_mobile_number, null: false
      t.string :customer_first_name, null: false
      t.string :customer_last_name, null: false
      t.integer :delivery_method, null: false
      t.text :delivery_notes
      t.boolean :prescription_required, null: false, default: false
      t.datetime :submitted_at, null: false
      t.datetime :confirmed_at
      t.datetime :cancelled_at
      t.timestamps
    end
    add_index :orders, :number, unique: true
    add_index :orders, %i[user_id submitted_at]
    add_check_constraint :orders, "status IN (0,1,2,3,4,5,6,7,8)", name: "orders_status_valid"
    add_check_constraint :orders, "payment_method IN (0,1,2)", name: "orders_payment_method_valid"
    add_check_constraint :orders, "payment_status IN (0,1,2,3,4)", name: "orders_payment_status_valid"
    add_check_constraint :orders, "delivery_method IN (0,1,2)", name: "orders_delivery_method_valid"
    add_check_constraint :orders, "currency = 'EGP'", name: "orders_currency_valid"
    add_check_constraint :orders, "subtotal_cents >= 0 AND discount_cents >= 0 AND delivery_fee_cents >= 0 AND total_cents >= 0", name: "orders_money_nonnegative"

    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: { on_delete: :cascade }
      t.references :product, null: true, foreign_key: { on_delete: :nullify }
      t.string :product_name, null: false
      t.string :product_slug, null: false
      t.string :brand_name, null: false
      t.string :category_name, null: false
      t.integer :unit_price_cents, null: false
      t.integer :compare_at_price_cents
      t.integer :discount_cents, null: false, default: 0
      t.integer :quantity, null: false
      t.integer :line_total_cents, null: false
      t.boolean :requires_prescription, null: false, default: false
      t.timestamps
    end
    add_check_constraint :order_items, "quantity > 0", name: "order_items_quantity_positive"
    add_check_constraint :order_items, "unit_price_cents >= 0 AND discount_cents >= 0 AND line_total_cents >= 0", name: "order_items_money_nonnegative"

    create_table :order_addresses do |t|
      t.references :order, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.string :label, null: false
      t.string :recipient_name, null: false
      t.string :mobile_number, null: false
      t.string :governorate, null: false
      t.string :city, null: false
      t.string :district
      t.string :street, null: false
      t.string :building_number, null: false
      t.string :floor
      t.string :apartment
      t.string :landmark
      t.string :postal_code
      t.text :delivery_notes
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.timestamps
    end

    create_table :prescriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.integer :status, null: false, default: 0
      t.datetime :submitted_at, null: false
      t.datetime :reviewed_at
      t.references :reviewed_by, null: true, foreign_key: { to_table: :users }
      t.text :rejection_reason
      t.text :customer_notes
      t.timestamps
    end
    add_check_constraint :prescriptions, "status IN (0,1,2,3,4)", name: "prescriptions_status_valid"

    create_table :inventory_reservations do |t|
      t.references :order, null: false, foreign_key: { on_delete: :cascade }
      t.references :order_item, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.integer :status, null: false, default: 0
      t.datetime :expires_at
      t.datetime :released_at
      t.datetime :consumed_at
      t.timestamps
    end
    add_index :inventory_reservations, %i[product_id status]
    add_check_constraint :inventory_reservations, "quantity > 0", name: "inventory_reservations_quantity_positive"
    add_check_constraint :inventory_reservations, "status IN (0,1,2)", name: "inventory_reservations_status_valid"

    add_check_constraint :products, "stock_quantity >= 0", name: "products_stock_nonnegative"
  end
end
