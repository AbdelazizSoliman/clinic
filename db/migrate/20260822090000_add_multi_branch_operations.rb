class AddMultiBranchOperations < ActiveRecord::Migration[8.1]
  DEFAULT_BRANCH_CODE = "MAIN"

  def up
    create_table :branches do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :arabic_name
      t.text :address
      t.string :phone
      t.boolean :active, null: false, default: true
      t.string :timezone, null: false, default: "Africa/Cairo"
      t.boolean :default, null: false, default: false
      t.boolean :fulfilment_enabled, null: false, default: true
      t.boolean :pos_enabled, null: false, default: true
      t.boolean :purchasing_enabled, null: false, default: true
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :branches, :code, unique: true
    add_index :branches, :default, unique: true, where: '"default" = TRUE', name: :index_branches_one_default

    execute <<~SQL
      INSERT INTO branches (code, name, arabic_name, active, timezone, "default", fulfilment_enabled, pos_enabled, purchasing_enabled, lock_version, created_at, updated_at)
      VALUES ('#{DEFAULT_BRANCH_CODE}', 'Main Branch', 'الفرع الرئيسي', TRUE, 'Africa/Cairo', TRUE, TRUE, TRUE, TRUE, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL

    %i[inventory_batches inventory_movements inventory_reservations orders fulfilments pos_sales cashier_sessions purchase_orders purchase_receipts return_requests loyalty_ledger_entries wallet_ledger_entries].each do |table|
      add_reference table, :branch, foreign_key: true, index: true
      execute "UPDATE #{table} SET branch_id = (SELECT id FROM branches WHERE code = '#{DEFAULT_BRANCH_CODE}')"
      change_column_null table, :branch_id, false
    end

    add_reference :users, :default_branch, foreign_key: { to_table: :branches }, index: true
    execute "UPDATE users SET default_branch_id = (SELECT id FROM branches WHERE code = '#{DEFAULT_BRANCH_CODE}') WHERE role <> 0"

    create_table :branch_memberships do |t|
      t.references :branch, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :branch_memberships, %i[user_id branch_id], unique: true
    execute <<~SQL
      INSERT INTO branch_memberships (branch_id, user_id, active, created_at, updated_at)
      SELECT (SELECT id FROM branches WHERE code = '#{DEFAULT_BRANCH_CODE}'), id, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM users WHERE role <> 0
    SQL

    add_reference :inventory_batches, :source_inventory_batch, foreign_key: { to_table: :inventory_batches }, index: true
    remove_index :inventory_batches, :batch_number
    add_index :inventory_batches, %i[branch_id batch_number], unique: true
    add_index :inventory_batches, %i[branch_id product_id expiry_date received_at], name: :index_inventory_batches_branch_fefo

    create_table :stock_transfers do |t|
      t.string :number, null: false
      t.references :source_branch, null: false, foreign_key: { to_table: :branches }
      t.references :destination_branch, null: false, foreign_key: { to_table: :branches }
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :submitted_by, foreign_key: { to_table: :users }
      t.references :dispatched_by, foreign_key: { to_table: :users }
      t.references :received_by, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.datetime :submitted_at
      t.datetime :dispatched_at
      t.datetime :received_at
      t.datetime :closed_at
      t.text :notes
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :stock_transfers, :number, unique: true
    add_check_constraint :stock_transfers, "source_branch_id <> destination_branch_id", name: :stock_transfers_distinct_branches
    add_check_constraint :stock_transfers, "status BETWEEN 0 AND 5", name: :stock_transfers_status_valid

    create_table :stock_transfer_items do |t|
      t.references :stock_transfer, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :requested_quantity, null: false
      t.integer :dispatched_quantity, null: false, default: 0
      t.integer :received_quantity, null: false, default: 0
      t.timestamps
    end
    add_index :stock_transfer_items, %i[stock_transfer_id product_id], unique: true
    add_check_constraint :stock_transfer_items, "requested_quantity > 0 AND dispatched_quantity >= 0 AND received_quantity >= 0 AND dispatched_quantity <= requested_quantity AND received_quantity <= dispatched_quantity", name: :stock_transfer_items_quantities_valid

    create_table :stock_transfer_batch_allocations do |t|
      t.references :stock_transfer_item, null: false, foreign_key: true
      t.references :source_inventory_batch, null: false, foreign_key: { to_table: :inventory_batches }
      t.references :destination_inventory_batch, foreign_key: { to_table: :inventory_batches }
      t.references :out_movement, foreign_key: { to_table: :inventory_movements }
      t.references :in_movement, foreign_key: { to_table: :inventory_movements }
      t.integer :quantity, null: false
      t.timestamps
    end
    add_index :stock_transfer_batch_allocations, %i[stock_transfer_item_id source_inventory_batch_id], unique: true, name: :index_transfer_allocations_unique_source_batch
    add_check_constraint :stock_transfer_batch_allocations, "quantity > 0", name: :stock_transfer_allocations_quantity_positive

    remove_check_constraint :inventory_movements, name: :inventory_movements_type_valid
    add_check_constraint :inventory_movements, "movement_type BETWEEN 0 AND 18", name: :inventory_movements_type_valid
  end

  def down
    remove_check_constraint :inventory_movements, name: :inventory_movements_type_valid
    add_check_constraint :inventory_movements, "movement_type BETWEEN 0 AND 16", name: :inventory_movements_type_valid
    drop_table :stock_transfer_batch_allocations
    drop_table :stock_transfer_items
    drop_table :stock_transfers
    remove_index :inventory_batches, name: :index_inventory_batches_branch_fefo
    remove_index :inventory_batches, column: %i[branch_id batch_number]
    add_index :inventory_batches, :batch_number, unique: true
    remove_reference :inventory_batches, :source_inventory_batch
    drop_table :branch_memberships
    remove_reference :users, :default_branch
    %i[wallet_ledger_entries loyalty_ledger_entries return_requests purchase_receipts purchase_orders cashier_sessions pos_sales fulfilments orders inventory_reservations inventory_movements inventory_batches].each do |table|
      remove_reference table, :branch
    end
    drop_table :branches
  end
end
