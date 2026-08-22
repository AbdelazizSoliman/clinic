class AddSaasMultiTenancy < ActiveRecord::Migration[8.1]
  TENANT_TABLES = %i[
    active_ingredients addresses admin_audit_events branches brands cart_items carts cashier_sessions categories
    coupons delivery_methods delivery_slots delivery_zone_districts delivery_zones drug_safety_acknowledgements
    drug_safety_evaluations drug_safety_findings drug_safety_rule_conditions drug_safety_rules fulfilments
    inventory_batch_events inventory_batches inventory_movements inventory_reservation_allocations
    inventory_reservations loyalty_accounts loyalty_ledger_entries loyalty_point_allocations loyalty_rules
    notifications order_addresses order_events order_follow_up_messages order_follow_ups order_items
    order_promotions orders patient_allergies patient_clinical_profiles pharmacy_settings pos_payments
    pos_sale_batch_allocations pos_sale_items pos_sales prescription_decisions prescription_review_items
    prescription_reviews prescriptions product_active_ingredients product_images product_price_changes products
    promotion_audit_events promotion_brands promotion_categories promotion_exclusions promotion_products
    promotion_redemptions promotions purchase_order_events purchase_order_items purchase_orders
    purchase_receipt_items purchase_receipts refunds report_export_events report_exports
    return_item_batch_allocations return_items return_requests search_events search_synonyms settings_audit_events
    stock_transfer_batch_allocations stock_transfer_items stock_transfers suppliers therapeutic_substitutions
    transactional_email_deliveries user_audit_events user_invitations users wallet_accounts wallet_ledger_entries
    wishlist_items branch_memberships
  ].freeze

  def up
    create_table :organizations do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.string :timezone, null: false, default: "Africa/Cairo"
      t.string :currency, null: false, default: "EGP"
      t.string :locale, null: false, default: "ar"
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :organizations, :code, unique: true
    execute <<~SQL
      INSERT INTO organizations (code, name, active, timezone, currency, locale, lock_version, created_at, updated_at)
      VALUES ('DEFAULT', 'Default Pharmacy Organization', TRUE, 'Africa/Cairo', 'EGP', 'ar', 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
    organization_id = select_value("SELECT id FROM organizations WHERE code = 'DEFAULT'").to_i
    TENANT_TABLES.each do |table|
      add_reference table, :organization, null: false, default: organization_id, foreign_key: true, index: true
    end

    remove_index :branches, :code
    remove_index :branches, name: :index_branches_one_default
    add_index :branches, %i[organization_id code], unique: true
    add_index :branches, %i[organization_id default], unique: true, where: '"default" = TRUE', name: :index_branches_one_default_per_org
    remove_index :pharmacy_settings, :singleton_key
    add_index :pharmacy_settings, %i[organization_id singleton_key], unique: true
  end

  def down
    remove_index :pharmacy_settings, column: %i[organization_id singleton_key]
    add_index :pharmacy_settings, :singleton_key, unique: true
    remove_index :branches, name: :index_branches_one_default_per_org
    remove_index :branches, column: %i[organization_id code]
    add_index :branches, :code, unique: true
    add_index :branches, :default, unique: true, where: '"default" = TRUE', name: :index_branches_one_default
    TENANT_TABLES.reverse_each { |table| remove_reference table, :organization }
    drop_table :organizations
  end
end
