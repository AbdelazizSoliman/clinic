class AddLoyaltyAndWallet < ActiveRecord::Migration[8.1]
  def change
    create_table :loyalty_accounts do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.integer :status, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_check_constraint :loyalty_accounts, "status IN (0, 1)", name: "loyalty_accounts_status_valid"

    create_table :wallet_accounts do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.integer :status, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_check_constraint :wallet_accounts, "status IN (0, 1)", name: "wallet_accounts_status_valid"

    create_table :loyalty_rules do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.integer :rule_type, null: false
      t.boolean :active, null: false, default: true
      t.integer :points_awarded
      t.bigint :spend_threshold_cents
      t.integer :redemption_points
      t.bigint :redemption_value_cents
      t.integer :minimum_redemption_points
      t.integer :maximum_redemption_points
      t.bigint :minimum_eligible_spend_cents, null: false, default: 0
      t.integer :expiration_days
      t.datetime :effective_from
      t.datetime :effective_to
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :loyalty_rules, :code, unique: true
    add_index :loyalty_rules, %i[rule_type active effective_from effective_to], name: "index_loyalty_rules_effective"
    add_check_constraint :loyalty_rules, "rule_type IN (0, 1)", name: "loyalty_rules_type_valid"
    add_check_constraint :loyalty_rules, "minimum_eligible_spend_cents >= 0", name: "loyalty_rules_minimum_spend_valid"
    add_check_constraint :loyalty_rules, "effective_to IS NULL OR effective_from IS NULL OR effective_to > effective_from", name: "loyalty_rules_dates_valid"

    create_table :loyalty_ledger_entries do |t|
      t.references :loyalty_account, null: false, foreign_key: true
      t.integer :entry_type, null: false
      t.integer :points, null: false
      t.references :source, polymorphic: true
      t.references :actor, foreign_key: { to_table: :users }
      t.references :reversal_of, foreign_key: { to_table: :loyalty_ledger_entries }
      t.string :reason, null: false
      t.datetime :occurred_at, null: false
      t.datetime :expires_at
      t.string :idempotency_key, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :loyalty_ledger_entries, :idempotency_key, unique: true, name: "index_loyalty_entries_on_key"
    add_index :loyalty_ledger_entries, %i[loyalty_account_id occurred_at], name: "index_loyalty_entries_history"
    add_index :loyalty_ledger_entries, %i[source_type source_id entry_type], name: "index_loyalty_entries_source"
    add_check_constraint :loyalty_ledger_entries, "entry_type BETWEEN 0 AND 6", name: "loyalty_entries_type_valid"
    add_check_constraint :loyalty_ledger_entries, "points > 0", name: "loyalty_entries_points_positive"
    add_check_constraint :loyalty_ledger_entries, "expires_at IS NULL OR expires_at > occurred_at", name: "loyalty_entries_expiry_valid"

    create_table :loyalty_point_allocations do |t|
      t.references :earn_entry, null: false, foreign_key: { to_table: :loyalty_ledger_entries }
      t.references :debit_entry, null: false, foreign_key: { to_table: :loyalty_ledger_entries }
      t.integer :points, null: false
      t.timestamps
    end
    add_index :loyalty_point_allocations, %i[earn_entry_id debit_entry_id], unique: true, name: "index_loyalty_allocations_unique"
    add_check_constraint :loyalty_point_allocations, "points > 0", name: "loyalty_allocations_points_positive"

    create_table :wallet_ledger_entries do |t|
      t.references :wallet_account, null: false, foreign_key: true
      t.integer :entry_type, null: false
      t.bigint :amount_cents, null: false
      t.references :source, polymorphic: true
      t.references :actor, foreign_key: { to_table: :users }
      t.references :reversal_of, foreign_key: { to_table: :wallet_ledger_entries }
      t.string :reason, null: false
      t.datetime :occurred_at, null: false
      t.string :idempotency_key, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :wallet_ledger_entries, :idempotency_key, unique: true, name: "index_wallet_entries_on_key"
    add_index :wallet_ledger_entries, %i[wallet_account_id occurred_at], name: "index_wallet_entries_history"
    add_index :wallet_ledger_entries, %i[source_type source_id entry_type], name: "index_wallet_entries_source"
    add_check_constraint :wallet_ledger_entries, "entry_type BETWEEN 0 AND 5", name: "wallet_entries_type_valid"
    add_check_constraint :wallet_ledger_entries, "amount_cents > 0", name: "wallet_entries_amount_positive"

    add_reference :pos_sales, :customer, foreign_key: { to_table: :users }
    add_column :pos_sales, :loyalty_points_redeemed, :integer, null: false, default: 0
    add_column :pos_sales, :loyalty_discount_cents, :bigint, null: false, default: 0
    add_column :pos_sales, :wallet_paid_cents, :bigint, null: false, default: 0
    remove_check_constraint :pos_sales, "subtotal_cents >= 0 AND automatic_discount_cents >= 0 AND manual_discount_cents >= 0 AND tax_cents >= 0 AND total_cents >= 0", name: "pos_sales_money_nonnegative"
    remove_check_constraint :pos_sales, "total_cents = (subtotal_cents - automatic_discount_cents - manual_discount_cents + tax_cents)", name: "pos_sales_total_consistent"
    add_check_constraint :pos_sales, "subtotal_cents >= 0 AND automatic_discount_cents >= 0 AND manual_discount_cents >= 0 AND loyalty_discount_cents >= 0 AND wallet_paid_cents >= 0 AND tax_cents >= 0 AND total_cents >= 0", name: "pos_sales_money_nonnegative"
    add_check_constraint :pos_sales, "total_cents = subtotal_cents - automatic_discount_cents - manual_discount_cents - loyalty_discount_cents + tax_cents", name: "pos_sales_total_consistent"
    add_check_constraint :pos_sales, "loyalty_points_redeemed >= 0 AND wallet_paid_cents <= total_cents", name: "pos_sales_loyalty_wallet_valid"

    remove_check_constraint :pos_payments, "payment_method = ANY (ARRAY[0, 1])", name: "pos_payments_method_valid"
    remove_check_constraint :pos_payments, "payment_method = 0 AND tendered_cents >= amount_cents AND change_cents = (tendered_cents - amount_cents) OR payment_method = 1 AND tendered_cents IS NULL AND change_cents = 0", name: "pos_payments_tender_consistent"
    add_check_constraint :pos_payments, "payment_method IN (0, 1, 2)", name: "pos_payments_method_valid"
    add_check_constraint :pos_payments, "payment_method = 0 AND tendered_cents >= amount_cents AND change_cents = tendered_cents - amount_cents OR payment_method IN (1, 2) AND tendered_cents IS NULL AND change_cents = 0", name: "pos_payments_tender_consistent"

    add_column :orders, :loyalty_points_redeemed, :integer, null: false, default: 0
    add_column :orders, :loyalty_discount_cents, :integer, null: false, default: 0
    add_column :orders, :wallet_paid_cents, :integer, null: false, default: 0
    add_column :orders, :cash_on_delivery_due_cents, :integer, null: false, default: 0
    reversible do |direction|
      direction.up { execute "UPDATE orders SET cash_on_delivery_due_cents = total_cents" }
    end
    add_check_constraint :orders, "loyalty_points_redeemed >= 0 AND loyalty_discount_cents >= 0 AND wallet_paid_cents >= 0 AND cash_on_delivery_due_cents >= 0", name: "orders_loyalty_wallet_nonnegative"
    add_check_constraint :orders, "wallet_paid_cents + cash_on_delivery_due_cents = total_cents", name: "orders_payment_breakdown_valid"

    remove_check_constraint :refunds, "payment_method BETWEEN 0 AND 2", name: "refunds_method_valid"
    add_check_constraint :refunds, "payment_method BETWEEN 0 AND 3", name: "refunds_method_valid"
  end
end
