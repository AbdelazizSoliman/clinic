class EnforceTenantRelationships < ActiveRecord::Migration[8.1]
  PARENTS = %i[branches users products suppliers inventory_batches orders cashier_sessions pos_sales purchase_orders
    return_requests loyalty_accounts wallet_accounts].freeze

  COMPOSITE_FOREIGN_KEYS = [
    [ :inventory_batches, %i[organization_id branch_id], :branches ],
    [ :inventory_batches, %i[organization_id product_id], :products ],
    [ :inventory_reservations, %i[organization_id branch_id], :branches ],
    [ :inventory_reservations, %i[organization_id product_id], :products ],
    [ :orders, %i[organization_id branch_id], :branches ],
    [ :orders, %i[organization_id user_id], :users ],
    [ :cashier_sessions, %i[organization_id branch_id], :branches ],
    [ :cashier_sessions, %i[organization_id user_id], :users ],
    [ :pos_sales, %i[organization_id branch_id], :branches ],
    [ :pos_sales, %i[organization_id cashier_session_id], :cashier_sessions ],
    [ :purchase_orders, %i[organization_id branch_id], :branches ],
    [ :purchase_orders, %i[organization_id supplier_id], :suppliers ],
    [ :purchase_receipts, %i[organization_id purchase_order_id], :purchase_orders ],
    [ :stock_transfers, %i[organization_id source_branch_id], :branches ],
    [ :stock_transfers, %i[organization_id destination_branch_id], :branches ],
    [ :loyalty_ledger_entries, %i[organization_id loyalty_account_id], :loyalty_accounts ],
    [ :wallet_ledger_entries, %i[organization_id wallet_account_id], :wallet_accounts ]
  ].freeze

  def up
    PARENTS.each { |table| add_index table, %i[organization_id id], unique: true, name: "idx_#{table}_tenant_identity" }
    COMPOSITE_FOREIGN_KEYS.each do |from, columns, to|
      add_foreign_key from, to, column: columns, primary_key: %i[organization_id id],
        name: "fk_#{from}_#{columns.last}_tenant"
    end
    scope_catalog_indexes
  end

  def down
    restore_catalog_indexes
    COMPOSITE_FOREIGN_KEYS.reverse_each do |from, columns, _to|
      remove_foreign_key from, name: "fk_#{from}_#{columns.last}_tenant"
    end
    PARENTS.reverse_each { |table| remove_index table, name: "idx_#{table}_tenant_identity" }
  end

  private

  def scope_catalog_indexes
    remove_index :products, :slug
    remove_index :products, :sku
    remove_index :products, :barcode
    add_index :products, %i[organization_id slug], unique: true
    add_index :products, %i[organization_id sku], unique: true, where: "sku IS NOT NULL"
    add_index :products, %i[organization_id barcode], unique: true, where: "barcode IS NOT NULL"
    remove_index :brands, :slug
    remove_index :categories, :slug
    add_index :brands, %i[organization_id slug], unique: true
    add_index :categories, %i[organization_id slug], unique: true
    remove_index :suppliers, name: :index_suppliers_on_lower_code
    add_index :suppliers, "organization_id, lower(code)", unique: true, name: :index_suppliers_tenant_lower_code
  end

  def restore_catalog_indexes
    remove_index :suppliers, name: :index_suppliers_tenant_lower_code
    add_index :suppliers, "lower(code)", unique: true, name: :index_suppliers_on_lower_code
    remove_index :categories, column: %i[organization_id slug]
    remove_index :brands, column: %i[organization_id slug]
    add_index :categories, :slug, unique: true
    add_index :brands, :slug, unique: true
    remove_index :products, column: %i[organization_id barcode]
    remove_index :products, column: %i[organization_id sku]
    remove_index :products, column: %i[organization_id slug]
    add_index :products, :barcode, unique: true, where: "barcode IS NOT NULL"
    add_index :products, :sku, unique: true, where: "sku IS NOT NULL"
    add_index :products, :slug, unique: true
  end
end
