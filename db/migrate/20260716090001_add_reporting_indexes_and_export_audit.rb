class AddReportingIndexesAndExportAudit < ActiveRecord::Migration[7.2]
  REPORT_TYPES = %w[sales orders products inventory promotions customers prescriptions fulfilments].freeze

  def change
    create_table :report_export_events do |t|
      t.references :user, null: false, foreign_key: true
      t.string :report_type, null: false
      t.string :format, null: false, default: "csv"
      t.datetime :range_start, null: false
      t.datetime :range_end, null: false
      t.jsonb :filters, null: false, default: {}
      t.integer :row_count, null: false, default: 0
      t.timestamps
    end
    add_check_constraint :report_export_events, "report_type IN (#{REPORT_TYPES.map { |type| quote(type) }.join(',')})", name: "report_export_events_type_valid"
    add_check_constraint :report_export_events, "format IN ('csv')", name: "report_export_events_format_valid"
    add_check_constraint :report_export_events, "range_end > range_start AND row_count >= 0", name: "report_export_events_range_rows_valid"
    add_index :report_export_events, %i[user_id created_at]
    add_index :orders, %i[status submitted_at], name: "index_orders_reporting_status_submitted"
    add_index :orders, %i[user_id submitted_at], name: "index_orders_reporting_user_submitted"
    add_index :order_items, %i[product_id order_id], name: "index_order_items_reporting_product_order"
    add_index :inventory_movements, %i[movement_type created_at], name: "index_inventory_movements_reporting_type_time"
    add_index :inventory_reservations, %i[status product_id], name: "index_inventory_reservations_reporting_status_product"
    add_index :prescriptions, %i[status submitted_at], name: "index_prescriptions_reporting_status_submitted"
    add_index :fulfilments, %i[status created_at], name: "index_fulfilments_reporting_status_created"
    add_index :order_events, %i[event_type created_at], name: "index_order_events_reporting_type_time"
    add_index :promotion_redemptions, %i[status redeemed_at], name: "index_redemptions_reporting_status_time"
  end
end
