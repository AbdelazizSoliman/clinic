class AddUserAdministrationAndSettings < ActiveRecord::Migration[7.2]
  def change
    change_table :users, bulk: true do |t|
      t.integer :failed_attempts, null: false, default: 0
      t.string :unlock_token
      t.datetime :locked_at
      t.datetime :last_sign_in_at
      t.integer :sign_in_count, null: false, default: 0
      t.integer :session_version, null: false, default: 0
    end
    add_index :users, :unlock_token, unique: true
    add_index :users, %i[role active]
    add_index :users, :last_sign_in_at

    create_table :user_invitations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.string :token_digest, null: false
      t.datetime :sent_at, null: false
      t.datetime :accepted_at
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.integer :attempts_count, null: false, default: 0
      t.timestamps
    end
    add_index :user_invitations, :token_digest, unique: true
    add_index :user_invitations, :expires_at
    add_check_constraint :user_invitations, "attempts_count >= 0", name: "user_invitations_attempts_nonnegative"

    create_table :user_audit_events do |t|
      t.references :user, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.jsonb :old_values, null: false, default: {}
      t.jsonb :new_values, null: false, default: {}
      t.text :reason
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :user_audit_events, %i[user_id created_at]
    add_check_constraint :user_audit_events,
      "action IN ('invited','invitation_resent','invitation_revoked','invitation_accepted','activated','deactivated','role_changed','profile_updated_by_admin','account_unlocked','password_reset_requested_by_admin','bootstrap_admin')",
      name: "user_audit_events_action_valid"

    create_table :pharmacy_settings do |t|
      t.integer :singleton_key, null: false, default: 1
      t.string :pharmacy_name, null: false, default: "صيدليتي"
      t.string :legal_name
      t.string :support_email
      t.string :support_mobile
      t.text :address_summary
      t.string :support_hours
      t.text :footer_text
      t.string :default_currency, null: false, default: "EGP"
      t.string :default_locale, null: false, default: "ar"
      t.string :time_zone, null: false, default: "Africa/Cairo"
      t.string :order_number_prefix, null: false, default: "PH"
      t.boolean :prescription_review_enabled, null: false, default: true
      t.boolean :guest_cart_enabled, null: false, default: true
      t.boolean :customer_registration_enabled, null: false, default: true
      t.integer :default_low_stock_threshold, null: false, default: 5
      t.integer :default_maximum_order_quantity, null: false, default: 10
      t.integer :default_reservation_minutes, null: false, default: 30
      t.integer :pending_prescription_reservation_hours, null: false, default: 24
      t.string :sender_email
      t.string :sender_name
      t.boolean :maintenance_mode, null: false, default: false
      t.text :maintenance_message
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :pharmacy_settings, :singleton_key, unique: true
    add_check_constraint :pharmacy_settings, "singleton_key = 1", name: "pharmacy_settings_singleton"
    add_check_constraint :pharmacy_settings, "default_low_stock_threshold >= 0 AND default_maximum_order_quantity BETWEEN 1 AND 100", name: "pharmacy_settings_product_defaults"
    add_check_constraint :pharmacy_settings, "default_reservation_minutes BETWEEN 5 AND 1440 AND pending_prescription_reservation_hours BETWEEN 1 AND 168", name: "pharmacy_settings_reservation_defaults"

    create_table :settings_audit_events do |t|
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false, default: "updated"
      t.jsonb :old_values, null: false, default: {}
      t.jsonb :new_values, null: false, default: {}
      t.text :reason
      t.datetime :created_at, null: false
    end
    add_index :settings_audit_events, :created_at
  end
end
