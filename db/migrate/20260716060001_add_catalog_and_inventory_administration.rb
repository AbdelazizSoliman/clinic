class AddCatalogAndInventoryAdministration < ActiveRecord::Migration[7.2]
  def change
    remove_check_constraint :users, name: "users_role_valid"
    add_check_constraint :users, "role = ANY (ARRAY[0, 1, 2, 3, 4])", name: "users_role_valid"

    change_table :categories, bulk: true do |t|
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
    end
    add_check_constraint :categories, "position >= 0", name: "categories_position_nonnegative"
    add_index :categories, %i[active position]

    change_table :brands, bulk: true do |t|
      t.text :description
      t.boolean :active, null: false, default: true
      t.string :website_url
      t.integer :lock_version, null: false, default: 0
    end
    add_index :brands, :active

    change_table :products, bulk: true do |t|
      t.string :active_ingredient
      t.string :dosage_form
      t.string :strength
      t.string :manufacturer
      t.string :sku
      t.string :barcode
      t.decimal :cost_price, precision: 10, scale: 2
      t.integer :low_stock_threshold, null: false, default: 5
      t.integer :maximum_order_quantity, null: false, default: 10
      t.boolean :pharmacist_review_required, null: false, default: false
      t.boolean :cold_chain_required, null: false, default: false
      t.datetime :published_at
      t.datetime :discontinued_at
      t.integer :lock_version, null: false, default: 0
    end
    add_index :products, :sku, unique: true, where: "sku IS NOT NULL"
    add_index :products, :barcode, unique: true, where: "barcode IS NOT NULL"
    add_index :products, %i[active low_stock_threshold]
    add_check_constraint :products, "cost_price IS NULL OR cost_price >= 0", name: "products_cost_price_nonnegative"
    add_check_constraint :products, "low_stock_threshold >= 0", name: "products_low_stock_threshold_nonnegative"
    add_check_constraint :products, "maximum_order_quantity > 0", name: "products_maximum_order_quantity_positive"

    create_table :product_images do |t|
      t.references :product, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string :alt_text, null: false
      t.boolean :primary, null: false, default: false
      t.timestamps
    end
    add_index :product_images, %i[product_id position], unique: true
    add_index :product_images, :product_id, unique: true, where: '"primary" = true', name: "index_one_primary_image_per_product"
    add_check_constraint :product_images, "position >= 0", name: "product_images_position_nonnegative"

    create_table :product_price_changes do |t|
      t.references :product, null: false, foreign_key: true
      t.references :changed_by, null: false, foreign_key: { to_table: :users }
      t.integer :old_price_cents, null: false
      t.integer :new_price_cents, null: false
      t.integer :old_compare_at_price_cents
      t.integer :new_compare_at_price_cents
      t.integer :old_cost_price_cents
      t.integer :new_cost_price_cents
      t.text :reason, null: false
      t.integer :source, null: false, default: 0
      t.datetime :effective_at, null: false
      t.datetime :created_at, null: false
    end
    add_index :product_price_changes, %i[product_id effective_at]
    add_check_constraint :product_price_changes, "old_price_cents >= 0 AND new_price_cents >= 0", name: "price_changes_prices_nonnegative"

    create_table :inventory_movements do |t|
      t.references :product, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.integer :movement_type, null: false
      t.integer :quantity_delta, null: false
      t.integer :quantity_before, null: false
      t.integer :quantity_after, null: false
      t.text :reason, null: false
      t.references :reference, polymorphic: true
      t.jsonb :metadata, null: false, default: {}
      t.string :idempotency_key
      t.datetime :created_at, null: false
    end
    add_index :inventory_movements, %i[product_id created_at]
    add_index :inventory_movements, :idempotency_key, unique: true, where: "idempotency_key IS NOT NULL"
    add_check_constraint :inventory_movements, "quantity_delta <> 0", name: "inventory_movements_delta_nonzero"
    add_check_constraint :inventory_movements, "quantity_before >= 0 AND quantity_after >= 0", name: "inventory_movements_quantities_nonnegative"

    create_table :admin_audit_events do |t|
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.references :auditable, polymorphic: true, null: false
      t.string :action, null: false
      t.jsonb :changes, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :admin_audit_events, %i[auditable_type auditable_id created_at], name: "index_admin_audits_on_subject_and_created_at"
  end
end
