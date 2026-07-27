class AddPharmacyPos < ActiveRecord::Migration[8.1]
  def up
    create_table :cashier_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :identifier, null: false
      t.integer :status, null: false, default: 0
      t.datetime :opened_at, null: false
      t.datetime :closed_at
      t.bigint :opening_cash_cents, null: false, default: 0
      t.bigint :expected_cash_cents
      t.bigint :closing_cash_counted_cents
      t.bigint :cash_difference_cents
      t.text :notes
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :cashier_sessions, :identifier, unique: true
    add_index :cashier_sessions, :user_id, unique: true, where: "status = 0",
      name: "index_cashier_sessions_one_open_per_user"
    add_check_constraint :cashier_sessions, "status IN (0, 1)", name: "cashier_sessions_status_valid"
    add_check_constraint :cashier_sessions, "opening_cash_cents >= 0", name: "cashier_sessions_opening_cash_nonnegative"
    add_check_constraint :cashier_sessions,
      "(status = 0 AND closed_at IS NULL AND expected_cash_cents IS NULL AND closing_cash_counted_cents IS NULL AND cash_difference_cents IS NULL) OR " \
      "(status = 1 AND closed_at IS NOT NULL AND expected_cash_cents >= 0 AND closing_cash_counted_cents >= 0 AND cash_difference_cents = closing_cash_counted_cents - expected_cash_cents)",
      name: "cashier_sessions_close_consistent"

    create_table :pos_sales do |t|
      t.references :cashier_session, null: false, foreign_key: true
      t.references :cashier, null: false, foreign_key: { to_table: :users }
      t.string :number, null: false
      t.integer :status, null: false, default: 0
      t.string :currency, null: false, default: "EGP"
      t.bigint :subtotal_cents, null: false, default: 0
      t.bigint :automatic_discount_cents, null: false, default: 0
      t.bigint :manual_discount_cents, null: false, default: 0
      t.bigint :tax_cents, null: false, default: 0
      t.bigint :total_cents, null: false, default: 0
      t.string :pricing_calculation_version
      t.text :manual_discount_reason
      t.references :discount_approved_by, foreign_key: { to_table: :users }
      t.datetime :discount_approved_at
      t.string :completion_idempotency_key
      t.datetime :completed_at
      t.datetime :voided_at
      t.references :voided_by, foreign_key: { to_table: :users }
      t.text :void_reason
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :pos_sales, :number, unique: true
    add_index :pos_sales, :completion_idempotency_key, unique: true,
      where: "completion_idempotency_key IS NOT NULL", name: "index_pos_sales_on_completion_key"
    add_index :pos_sales, %i[status completed_at]
    add_check_constraint :pos_sales, "status IN (0, 1, 2)", name: "pos_sales_status_valid"
    add_check_constraint :pos_sales, "currency = 'EGP'", name: "pos_sales_currency_valid"
    add_check_constraint :pos_sales,
      "subtotal_cents >= 0 AND automatic_discount_cents >= 0 AND manual_discount_cents >= 0 AND tax_cents >= 0 AND total_cents >= 0",
      name: "pos_sales_money_nonnegative"
    add_check_constraint :pos_sales,
      "total_cents = subtotal_cents - automatic_discount_cents - manual_discount_cents + tax_cents",
      name: "pos_sales_total_consistent"

    create_table :pos_sale_items do |t|
      t.references :pos_sale, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.string :product_name, null: false
      t.string :product_sku
      t.string :product_barcode
      t.integer :quantity, null: false
      t.bigint :original_unit_price_cents, null: false
      t.bigint :unit_price_cents, null: false
      t.bigint :discount_cents, null: false, default: 0
      t.bigint :line_total_cents, null: false
      t.boolean :requires_prescription, null: false, default: false
      t.references :prescription_approved_by, foreign_key: { to_table: :users }
      t.datetime :prescription_approved_at
      t.text :prescription_approval_reason
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :pos_sale_items, %i[pos_sale_id product_id], unique: true
    add_check_constraint :pos_sale_items, "quantity > 0", name: "pos_sale_items_quantity_positive"
    add_check_constraint :pos_sale_items,
      "original_unit_price_cents >= 0 AND unit_price_cents >= 0 AND discount_cents >= 0 AND line_total_cents >= 0",
      name: "pos_sale_items_money_nonnegative"

    create_table :pos_payments do |t|
      t.references :pos_sale, null: false, foreign_key: true
      t.integer :payment_method, null: false
      t.bigint :amount_cents, null: false
      t.bigint :tendered_cents
      t.bigint :change_cents, null: false, default: 0
      t.string :external_reference
      t.timestamps
    end
    add_check_constraint :pos_payments, "payment_method IN (0, 1)", name: "pos_payments_method_valid"
    add_check_constraint :pos_payments, "amount_cents > 0", name: "pos_payments_amount_positive"
    add_check_constraint :pos_payments,
      "(payment_method = 0 AND tendered_cents >= amount_cents AND change_cents = tendered_cents - amount_cents) OR " \
      "(payment_method = 1 AND tendered_cents IS NULL AND change_cents = 0)",
      name: "pos_payments_tender_consistent"

    create_table :pos_sale_batch_allocations do |t|
      t.references :pos_sale_item, null: false, foreign_key: true
      t.references :inventory_batch, null: false, foreign_key: true
      t.references :inventory_movement, foreign_key: true
      t.integer :quantity, null: false
      t.bigint :unit_cost_cents
      t.timestamps
    end
    add_index :pos_sale_batch_allocations, %i[pos_sale_item_id inventory_batch_id],
      unique: true, name: "index_pos_allocations_unique_batch"
    add_check_constraint :pos_sale_batch_allocations, "quantity > 0", name: "pos_allocations_quantity_positive"
    add_check_constraint :pos_sale_batch_allocations,
      "unit_cost_cents IS NULL OR unit_cost_cents >= 0", name: "pos_allocations_cost_nonnegative"

    add_check_constraint :inventory_movements, "movement_type IN (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)",
      name: "inventory_movements_type_valid"
    remove_check_constraint :report_export_events, name: "report_export_events_type_valid"
    add_check_constraint :report_export_events,
      "report_type IN ('sales','orders','products','inventory','promotions','customers','prescriptions','fulfilments','purchasing','batches','pos')",
      name: "report_export_events_type_valid"
  end

  def down
    remove_check_constraint :report_export_events, name: "report_export_events_type_valid"
    add_check_constraint :report_export_events,
      "report_type IN ('sales','orders','products','inventory','promotions','customers','prescriptions','fulfilments','purchasing','batches')",
      name: "report_export_events_type_valid"
    remove_check_constraint :inventory_movements, name: "inventory_movements_type_valid"
    drop_table :pos_sale_batch_allocations
    drop_table :pos_payments
    drop_table :pos_sale_items
    drop_table :pos_sales
    drop_table :cashier_sessions
  end
end
