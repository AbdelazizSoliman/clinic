class AddDeliveryZonesAndFulfilment < ActiveRecord::Migration[7.2]
  def change
    create_table :delivery_zones do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.string :governorate, null: false
      t.string :city, null: false
      t.boolean :active, null: false, default: true
      t.integer :delivery_fee_cents, null: false, default: 0
      t.integer :free_delivery_threshold_cents
      t.integer :minimum_order_cents
      t.integer :estimated_min_minutes, null: false
      t.integer :estimated_max_minutes, null: false
      t.boolean :same_day_available, null: false, default: false
      t.boolean :scheduled_delivery_available, null: false, default: true
      t.boolean :cash_on_delivery_available, null: false, default: true
      t.integer :position, null: false, default: 0
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :delivery_zones, :code, unique: true
    add_index :delivery_zones, %i[governorate city name], unique: true
    add_index :delivery_zones, %i[active position]
    add_check_constraint :delivery_zones, "delivery_fee_cents >= 0 AND (free_delivery_threshold_cents IS NULL OR free_delivery_threshold_cents >= 0) AND (minimum_order_cents IS NULL OR minimum_order_cents >= 0)", name: "delivery_zones_money_nonnegative"
    add_check_constraint :delivery_zones, "estimated_min_minutes > 0 AND estimated_max_minutes >= estimated_min_minutes", name: "delivery_zones_estimate_valid"
    add_check_constraint :delivery_zones, "position >= 0", name: "delivery_zones_position_nonnegative"

    create_table :delivery_zone_districts do |t|
      t.references :delivery_zone, null: false, foreign_key: true
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :delivery_zone_districts, %i[delivery_zone_id normalized_name], unique: true, name: "index_zone_districts_on_zone_and_normalized_name"
    add_index :delivery_zone_districts, :normalized_name

    create_table :delivery_methods do |t|
      t.references :delivery_zone, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.integer :additional_fee_cents, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :delivery_methods, %i[delivery_zone_id code], unique: true
    add_check_constraint :delivery_methods, "additional_fee_cents >= 0 AND position >= 0", name: "delivery_methods_values_valid"

    create_table :delivery_slots do |t|
      t.references :delivery_zone, null: false, foreign_key: true
      t.date :delivery_date, null: false
      t.time :starts_at, null: false
      t.time :ends_at, null: false
      t.integer :capacity, null: false
      t.integer :booked_count, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :delivery_slots, %i[delivery_zone_id delivery_date starts_at], unique: true, name: "index_delivery_slots_unique_window"
    add_check_constraint :delivery_slots, "capacity > 0 AND booked_count >= 0 AND booked_count <= capacity", name: "delivery_slots_capacity_valid"
    add_check_constraint :delivery_slots, "ends_at > starts_at", name: "delivery_slots_window_valid"

    add_reference :orders, :delivery_zone, foreign_key: true
    add_reference :orders, :delivery_slot, foreign_key: true
    add_column :orders, :delivery_zone_code, :string
    add_column :orders, :delivery_zone_name, :string
    add_column :orders, :delivery_method_name, :string
    add_column :orders, :delivery_estimated_min_minutes, :integer
    add_column :orders, :delivery_estimated_max_minutes, :integer
    add_column :orders, :scheduled_for, :datetime

    create_table :fulfilments do |t|
      t.references :order, null: false, foreign_key: true, index: { unique: true }
      t.references :delivery_zone, foreign_key: true
      t.references :delivery_slot, foreign_key: true
      t.references :assigned_to, foreign_key: { to_table: :users }
      t.references :assigned_by, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.datetime :assigned_at
      t.datetime :picked_at
      t.datetime :dispatched_at
      t.datetime :delivered_at
      t.text :internal_notes
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :fulfilments, %i[status created_at]
    add_check_constraint :fulfilments, "status BETWEEN 0 AND 5", name: "fulfilments_status_valid"
  end
end
