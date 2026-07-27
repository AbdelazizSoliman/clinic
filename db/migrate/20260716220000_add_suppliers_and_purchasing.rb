class AddSuppliersAndPurchasing < ActiveRecord::Migration[8.1]
  def change
    create_table :suppliers do |t|
      t.string :name, null: false
      t.string :legal_name
      t.string :code, null: false
      t.string :contact_person
      t.string :phone
      t.string :email
      t.text :address
      t.string :tax_identifier
      t.string :payment_terms
      t.integer :lead_time_days
      t.text :notes
      t.boolean :active, null: false, default: true
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :suppliers, "lower(code)", unique: true, name: "index_suppliers_on_lower_code"
    add_index :suppliers, :active
    add_check_constraint :suppliers, "lead_time_days IS NULL OR lead_time_days >= 0", name: "suppliers_lead_time_nonnegative"

    create_table :purchase_orders do |t|
      t.references :supplier, null: false, foreign_key: true
      t.string :number, null: false
      t.integer :status, null: false, default: 0
      t.datetime :ordered_at
      t.date :expected_at
      t.datetime :submitted_at
      t.datetime :approved_at
      t.references :approved_by, foreign_key: { to_table: :users }
      t.datetime :received_at
      t.datetime :closed_at
      t.datetime :cancelled_at
      t.references :cancelled_by, foreign_key: { to_table: :users }
      t.text :cancellation_reason
      t.string :currency, null: false, default: "EGP"
      t.integer :subtotal_cents, null: false, default: 0
      t.integer :discount_total_cents, null: false, default: 0
      t.integer :tax_total_cents, null: false, default: 0
      t.integer :total_cents, null: false, default: 0
      t.text :notes
      t.text :internal_notes
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :purchase_orders, :number, unique: true
    add_index :purchase_orders, %i[status expected_at]
    add_index :purchase_orders, %i[supplier_id ordered_at]
    add_check_constraint :purchase_orders, "status >= 0 AND status <= 6", name: "purchase_orders_status_valid"
    add_check_constraint :purchase_orders, "currency = 'EGP'", name: "purchase_orders_currency_valid"
    add_check_constraint :purchase_orders, "subtotal_cents >= 0 AND discount_total_cents >= 0 AND tax_total_cents >= 0 AND total_cents >= 0", name: "purchase_orders_money_nonnegative"

    create_table :purchase_order_items do |t|
      t.references :purchase_order, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.string :product_name_snapshot, null: false
      t.string :sku_snapshot
      t.integer :ordered_quantity, null: false
      t.integer :received_quantity, null: false, default: 0
      t.integer :unit_cost_cents, null: false
      t.integer :discount_cents, null: false, default: 0
      t.integer :tax_cents, null: false, default: 0
      t.integer :line_total_cents, null: false
      t.text :notes
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :purchase_order_items, %i[purchase_order_id product_id], unique: true, name: "index_purchase_order_items_unique_product"
    add_check_constraint :purchase_order_items, "ordered_quantity > 0", name: "purchase_order_items_ordered_positive"
    add_check_constraint :purchase_order_items, "received_quantity >= 0 AND received_quantity <= ordered_quantity", name: "purchase_order_items_received_valid"
    add_check_constraint :purchase_order_items, "unit_cost_cents >= 0 AND discount_cents >= 0 AND tax_cents >= 0 AND line_total_cents >= 0", name: "purchase_order_items_money_nonnegative"

    create_table :purchase_receipts do |t|
      t.references :purchase_order, null: false, foreign_key: true
      t.string :reference, null: false
      t.references :received_by, null: false, foreign_key: { to_table: :users }
      t.datetime :received_at, null: false
      t.string :supplier_document_number
      t.text :notes
      t.string :idempotency_key, null: false
      t.timestamps
    end
    add_index :purchase_receipts, :reference, unique: true
    add_index :purchase_receipts, :idempotency_key, unique: true

    create_table :purchase_receipt_items do |t|
      t.references :purchase_receipt, null: false, foreign_key: true
      t.references :purchase_order_item, null: false, foreign_key: true
      t.references :inventory_movement, null: false, foreign_key: true,
        index: { unique: true, name: "index_purchase_receipt_items_unique_movement" }
      t.integer :quantity, null: false
      t.integer :unit_cost_cents, null: false
      t.timestamps
    end
    add_index :purchase_receipt_items, %i[purchase_receipt_id purchase_order_item_id], unique: true, name: "index_purchase_receipt_items_unique_line"
    add_check_constraint :purchase_receipt_items, "quantity > 0", name: "purchase_receipt_items_quantity_positive"
    add_check_constraint :purchase_receipt_items, "unit_cost_cents >= 0", name: "purchase_receipt_items_cost_nonnegative"

    create_table :purchase_order_events do |t|
      t.references :purchase_order, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.string :event_type, null: false
      t.string :from_status
      t.string :to_status
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :purchase_order_events, %i[purchase_order_id created_at]

    remove_check_constraint :report_export_events,
      "report_type IN ('sales','orders','products','inventory','promotions','customers','prescriptions','fulfilments')",
      name: "report_export_events_type_valid"
    add_check_constraint :report_export_events,
      "report_type IN ('sales','orders','products','inventory','promotions','customers','prescriptions','fulfilments','purchasing')",
      name: "report_export_events_type_valid"
  end
end
