class AddStaffOperations < ActiveRecord::Migration[7.2]
  def change
    remove_check_constraint :users, name: "users_role_valid"
    add_check_constraint :users, "role IN (0,1,2,3)", name: "users_role_valid"
    add_column :orders, :lock_version, :integer, null: false, default: 0
    add_column :prescriptions, :lock_version, :integer, null: false, default: 0
    add_column :prescriptions, :customer_message, :text
    add_column :prescriptions, :internal_notes, :text

    create_table :order_events do |t|
      t.references :order, null: false, foreign_key: { on_delete: :cascade }
      t.references :actor, null: true, foreign_key: { to_table: :users }
      t.string :event_type, null: false
      t.string :from_status
      t.string :to_status
      t.jsonb :metadata, null: false, default: {}
      t.boolean :customer_visible, null: false, default: false
      t.datetime :created_at, null: false
    end
    add_index :order_events, %i[order_id created_at]
    add_index :order_events, :event_type
    add_check_constraint :order_events, "event_type IN ('order_submitted','prescription_review_started','prescription_approved','prescription_partially_approved','prescription_rejected','order_confirmed','preparation_started','order_ready','out_for_delivery','delivered','cancelled','rejected','reservations_released','reservations_consumed')", name: "order_events_type_valid"
  end
end
