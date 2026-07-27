class AddBatchInventory < ActiveRecord::Migration[8.1]
  def up
    create_table :inventory_batches do |t|
      t.references :product, null: false, foreign_key: true
      t.references :supplier, foreign_key: true
      t.references :purchase_receipt, foreign_key: true
      t.references :purchase_receipt_item, foreign_key: true
      t.string :batch_number, null: false
      t.string :lot_number
      t.date :manufacture_date
      t.date :expiry_date, null: false
      t.datetime :received_at, null: false
      t.integer :original_quantity, null: false
      t.integer :on_hand_quantity, null: false
      t.integer :reserved_quantity, null: false, default: 0
      t.integer :unit_cost_cents
      t.datetime :quarantined_at
      t.references :quarantined_by, foreign_key: { to_table: :users }
      t.text :quarantine_reason
      t.text :notes
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :inventory_batches, :batch_number, unique: true
    add_index :inventory_batches, %i[product_id expiry_date received_at], name: "index_inventory_batches_fefo"
    add_index :inventory_batches, %i[expiry_date quarantined_at]
    add_check_constraint :inventory_batches, "original_quantity > 0", name: "inventory_batches_original_positive"
    add_check_constraint :inventory_batches,
      "on_hand_quantity >= 0 AND reserved_quantity >= 0 AND reserved_quantity <= on_hand_quantity",
      name: "inventory_batches_quantities_valid"
    add_check_constraint :inventory_batches,
      "manufacture_date IS NULL OR expiry_date > manufacture_date",
      name: "inventory_batches_expiry_after_manufacture"
    add_check_constraint :inventory_batches,
      "unit_cost_cents IS NULL OR unit_cost_cents >= 0",
      name: "inventory_batches_cost_nonnegative"
    add_check_constraint :inventory_batches,
      "(quarantined_at IS NULL AND quarantined_by_id IS NULL AND quarantine_reason IS NULL) OR (quarantined_at IS NOT NULL AND quarantine_reason IS NOT NULL)",
      name: "inventory_batches_quarantine_consistent"

    create_table :inventory_reservation_allocations do |t|
      t.references :inventory_reservation, null: false, foreign_key: true
      t.references :inventory_batch, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :inventory_reservation_allocations, %i[inventory_reservation_id inventory_batch_id],
      unique: true, name: "index_reservation_allocations_unique_batch"
    add_check_constraint :inventory_reservation_allocations, "quantity > 0",
      name: "inventory_reservation_allocations_quantity_positive"

    create_table :inventory_batch_events do |t|
      t.references :inventory_batch, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.string :event_type, null: false
      t.text :reason, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :inventory_batch_events, %i[inventory_batch_id created_at]
    add_check_constraint :inventory_batch_events,
      "event_type IN ('created','quarantined','quarantine_released','adjusted')",
      name: "inventory_batch_events_type_valid"

    remove_index :purchase_receipt_items, name: "index_purchase_receipt_items_unique_movement"
    add_index :purchase_receipt_items, :inventory_movement_id
    change_column_null :purchase_receipt_items, :inventory_movement_id, true

    add_reference :inventory_movements, :inventory_batch, foreign_key: true
    add_column :inventory_movements, :batch_quantity_before, :integer
    add_column :inventory_movements, :batch_quantity_after, :integer
    add_check_constraint :inventory_movements,
      "(inventory_batch_id IS NULL AND batch_quantity_before IS NULL AND batch_quantity_after IS NULL) OR " \
      "(inventory_batch_id IS NOT NULL AND batch_quantity_before >= 0 AND batch_quantity_after >= 0 AND batch_quantity_after = batch_quantity_before + quantity_delta)",
      name: "inventory_movements_batch_quantities_valid"

    add_column :pharmacy_settings, :near_expiry_threshold_days, :integer, null: false, default: 90
    add_check_constraint :pharmacy_settings, "near_expiry_threshold_days BETWEEN 1 AND 730",
      name: "pharmacy_settings_near_expiry_threshold_valid"

    remove_check_constraint :report_export_events, name: "report_export_events_type_valid"
    add_check_constraint :report_export_events,
      "report_type IN ('sales','orders','products','inventory','promotions','customers','prescriptions','fulfilments','purchasing','batches')",
      name: "report_export_events_type_valid"

    execute <<~SQL
      INSERT INTO inventory_batches
        (product_id, batch_number, lot_number, expiry_date, received_at, original_quantity,
         on_hand_quantity, reserved_quantity, notes, lock_version, created_at, updated_at)
      SELECT products.id, 'LEGACY-P' || products.id, 'LEGACY', DATE '2099-12-31',
        products.created_at, products.stock_quantity, products.stock_quantity,
        COALESCE(reserved.total, 0), 'Migrated product-level opening stock', 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM products
      LEFT JOIN (
        SELECT product_id, SUM(quantity) AS total
        FROM inventory_reservations
        WHERE status = 0
        GROUP BY product_id
      ) reserved ON reserved.product_id = products.id
      WHERE products.stock_quantity > 0
    SQL

    execute <<~SQL
      INSERT INTO inventory_reservation_allocations
        (inventory_reservation_id, inventory_batch_id, quantity, lock_version, created_at, updated_at)
      SELECT reservations.id, batches.id, reservations.quantity, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM inventory_reservations reservations
      JOIN inventory_batches batches
        ON batches.product_id = reservations.product_id AND batches.batch_number = 'LEGACY-P' || reservations.product_id
      WHERE reservations.status = 0
    SQL
  end

  def down
    remove_check_constraint :report_export_events, name: "report_export_events_type_valid"
    add_check_constraint :report_export_events,
      "report_type IN ('sales','orders','products','inventory','promotions','customers','prescriptions','fulfilments','purchasing')",
      name: "report_export_events_type_valid"
    remove_check_constraint :pharmacy_settings, name: "pharmacy_settings_near_expiry_threshold_valid"
    remove_column :pharmacy_settings, :near_expiry_threshold_days
    remove_check_constraint :inventory_movements, name: "inventory_movements_batch_quantities_valid"
    remove_column :inventory_movements, :batch_quantity_after
    remove_column :inventory_movements, :batch_quantity_before
    execute <<~SQL
      UPDATE purchase_receipt_items
      SET inventory_movement_id = (
        SELECT inventory_movements.id
        FROM inventory_batches
        JOIN inventory_movements ON inventory_movements.inventory_batch_id = inventory_batches.id
        WHERE inventory_batches.purchase_receipt_item_id = purchase_receipt_items.id
        ORDER BY inventory_movements.id
        LIMIT 1
      )
      WHERE inventory_movement_id IS NULL
    SQL
    remove_reference :inventory_movements, :inventory_batch, foreign_key: true
    change_column_null :purchase_receipt_items, :inventory_movement_id, false
    remove_index :purchase_receipt_items, :inventory_movement_id
    add_index :purchase_receipt_items, :inventory_movement_id, unique: true,
      name: "index_purchase_receipt_items_unique_movement"
    drop_table :inventory_reservation_allocations
    drop_table :inventory_batch_events, if_exists: true
    drop_table :inventory_batches
  end
end
