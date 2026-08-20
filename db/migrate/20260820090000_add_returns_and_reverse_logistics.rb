class AddReturnsAndReverseLogistics < ActiveRecord::Migration[8.1]
  def change
    add_column :inventory_batches, :returned_quarantine_quantity, :integer, null: false, default: 0
    add_check_constraint :inventory_batches,
      "returned_quarantine_quantity >= 0 AND returned_quarantine_quantity <= on_hand_quantity",
      name: "inventory_batches_returned_quarantine_valid"

    create_table :return_requests do |t|
      t.string :number, null: false
      t.references :source, polymorphic: true, null: false
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.text :customer_notes
      t.text :internal_notes
      t.datetime :submitted_at
      t.datetime :reviewed_at
      t.datetime :received_at
      t.datetime :closed_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :return_requests, :number, unique: true
    add_index :return_requests, %i[source_type source_id status], name: "index_returns_on_source_and_status"
    add_check_constraint :return_requests, "source_type IN ('Order', 'PosSale')", name: "returns_source_type_valid"
    add_check_constraint :return_requests, "status BETWEEN 0 AND 8", name: "returns_status_valid"

    create_table :return_items do |t|
      t.references :return_request, null: false, foreign_key: true
      t.references :source_item, polymorphic: true, null: false
      t.references :original_product, foreign_key: { to_table: :products }
      t.references :dispensed_product, foreign_key: { to_table: :products }
      t.integer :requested_quantity, null: false
      t.integer :approved_quantity, null: false, default: 0
      t.integer :received_quantity, null: false, default: 0
      t.bigint :unit_price_cents, null: false
      t.bigint :allocated_discount_cents, null: false, default: 0
      t.bigint :tax_cents, null: false, default: 0
      t.bigint :refundable_amount_cents, null: false
      t.integer :reason, null: false
      t.integer :condition, null: false, default: 5
      t.integer :disposition
      t.text :reason_notes
      t.references :inspected_by, foreign_key: { to_table: :users }
      t.datetime :inspected_at
      t.text :inspection_notes
      t.boolean :pharmacist_inspection_required, null: false, default: false
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_check_constraint :return_items, "source_item_type IN ('OrderItem', 'PosSaleItem')", name: "return_items_source_type_valid"
    add_check_constraint :return_items, "requested_quantity > 0 AND approved_quantity >= 0 AND approved_quantity <= requested_quantity AND received_quantity >= 0 AND received_quantity <= approved_quantity", name: "return_items_quantities_valid"
    add_check_constraint :return_items, "unit_price_cents >= 0 AND allocated_discount_cents >= 0 AND tax_cents >= 0 AND refundable_amount_cents >= 0", name: "return_items_money_valid"
    add_check_constraint :return_items, "reason BETWEEN 0 AND 6", name: "return_items_reason_valid"
    add_check_constraint :return_items, "condition BETWEEN 0 AND 5", name: "return_items_condition_valid"
    add_check_constraint :return_items, "disposition IS NULL OR disposition BETWEEN 0 AND 3", name: "return_items_disposition_valid"

    create_table :return_item_batch_allocations do |t|
      t.references :return_item, null: false, foreign_key: true
      t.references :original_allocation, polymorphic: true, null: false
      t.references :inventory_batch, null: false, foreign_key: true
      t.references :inventory_movement, foreign_key: true
      t.integer :quantity, null: false
      t.integer :disposition, null: false
      t.string :idempotency_key, null: false
      t.timestamps
    end
    add_index :return_item_batch_allocations, :idempotency_key, unique: true, name: "index_return_batch_allocations_on_key"
    add_index :return_item_batch_allocations, %i[original_allocation_type original_allocation_id], name: "index_return_batch_on_original_allocation"
    add_check_constraint :return_item_batch_allocations, "original_allocation_type IN ('InventoryReservationAllocation', 'PosSaleBatchAllocation')", name: "return_batch_original_type_valid"
    add_check_constraint :return_item_batch_allocations, "quantity > 0", name: "return_batch_quantity_positive"
    add_check_constraint :return_item_batch_allocations, "disposition BETWEEN 0 AND 3", name: "return_batch_disposition_valid"

    create_table :refunds do |t|
      t.references :return_request, null: false, foreign_key: true
      t.references :source, polymorphic: true, null: false
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.references :cashier_session, foreign_key: true
      t.bigint :amount_cents, null: false
      t.integer :payment_method, null: false
      t.integer :status, null: false, default: 0
      t.datetime :refunded_at
      t.string :external_reference
      t.string :idempotency_key, null: false
      t.text :notes
      t.timestamps
    end
    add_index :refunds, :idempotency_key, unique: true
    add_check_constraint :refunds, "source_type IN ('Order', 'PosSale')", name: "refunds_source_type_valid"
    add_check_constraint :refunds, "amount_cents > 0", name: "refunds_amount_positive"
    add_check_constraint :refunds, "payment_method BETWEEN 0 AND 2", name: "refunds_method_valid"
    add_check_constraint :refunds, "status BETWEEN 0 AND 3", name: "refunds_status_valid"

    add_column :inventory_movements, :return_movement, :boolean, null: false, default: false
    remove_check_constraint :inventory_movements, "movement_type = ANY (ARRAY[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])", name: "inventory_movements_type_valid"
    add_check_constraint :inventory_movements, "movement_type BETWEEN 0 AND 16", name: "inventory_movements_type_valid"
    remove_check_constraint :inventory_movements, "quantity_delta <> 0", name: "inventory_movements_delta_nonzero"
    add_check_constraint :inventory_movements,
      "quantity_delta <> 0 OR movement_type IN (15, 16)", name: "inventory_movements_delta_valid"
  end
end
