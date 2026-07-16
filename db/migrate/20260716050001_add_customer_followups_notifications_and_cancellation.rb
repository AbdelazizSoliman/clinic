class AddCustomerFollowupsNotificationsAndCancellation < ActiveRecord::Migration[7.2]
  EVENT_TYPES = %w[follow_up_opened customer_responded follow_up_resolved customer_cancelled staff_cancelled system_cancelled reservations_extended reservations_expired notification_sent].freeze

  def change
    add_reference :orders, :cancelled_by, foreign_key: { to_table: :users }
    add_column :orders, :cancellation_reason, :text
    add_column :orders, :cancellation_source, :integer

    create_table :order_follow_ups do |t|
      t.references :order, null: false, foreign_key: true
      t.references :prescription, foreign_key: true
      t.references :opened_by, null: false, foreign_key: { to_table: :users }
      t.references :resolved_by, foreign_key: { to_table: :users }
      t.integer :kind, null: false
      t.integer :status, null: false, default: 1
      t.string :subject, null: false
      t.text :customer_message, null: false
      t.text :internal_notes
      t.boolean :response_required, null: false, default: true
      t.datetime :responded_at
      t.datetime :resolved_at
      t.datetime :due_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :order_follow_ups, %i[status due_at]
    add_check_constraint :order_follow_ups, "kind BETWEEN 0 AND 5", name: "follow_ups_kind_valid"
    add_check_constraint :order_follow_ups, "status BETWEEN 0 AND 4", name: "follow_ups_status_valid"

    create_table :order_follow_up_messages do |t|
      t.references :order_follow_up, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.string :author_role, null: false
      t.text :body, null: false
      t.boolean :customer_visible, null: false, default: true
      t.datetime :created_at, null: false
    end

    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.references :notifiable, polymorphic: true, null: false
      t.string :kind, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.datetime :read_at
      t.jsonb :metadata, null: false, default: {}
      t.string :deduplication_key
      t.timestamps
    end
    add_index :notifications, %i[user_id read_at]
    add_index :notifications, :deduplication_key, unique: true, where: "deduplication_key IS NOT NULL"

    remove_check_constraint :order_events, name: "order_events_type_valid"
    all_types = %w[order_submitted prescription_review_started prescription_approved prescription_partially_approved prescription_rejected order_confirmed preparation_started order_ready out_for_delivery delivered cancelled rejected reservations_released reservations_consumed] + EVENT_TYPES
    quoted = all_types.map { |type| connection.quote(type) }.join(", ")
    add_check_constraint :order_events, "event_type IN (#{quoted})", name: "order_events_type_valid"
  end
end
