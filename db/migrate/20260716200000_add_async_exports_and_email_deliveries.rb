class AddAsyncExportsAndEmailDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :report_exports do |t|
      t.references :user, null: false, foreign_key: true
      t.string :report_type, null: false
      t.jsonb :filters, null: false, default: {}
      t.integer :status, null: false, default: 0
      t.integer :row_count
      t.datetime :requested_at, null: false
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :failed_at
      t.datetime :expires_at
      t.string :error_class
      t.string :deduplication_key, null: false
      t.timestamps
      t.index :deduplication_key
      t.index %i[user_id status created_at]
      t.index %i[status expires_at]
    end

    create_table :transactional_email_deliveries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :notification, foreign_key: true
      t.string :mailer, null: false
      t.string :action, null: false
      t.integer :status, null: false, default: 0
      t.integer :attempts_count, null: false, default: 0
      t.string :deduplication_key, null: false
      t.datetime :queued_at, null: false
      t.datetime :delivered_at
      t.datetime :failed_at
      t.string :last_error_class
      t.timestamps
      t.index :deduplication_key, unique: true
      t.index %i[status updated_at]
    end
  end
end
