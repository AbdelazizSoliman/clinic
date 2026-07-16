# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_07_16_090001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "addresses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "label", limit: 50, null: false
    t.string "recipient_name", limit: 120, null: false
    t.string "mobile_number", limit: 20, null: false
    t.string "governorate", limit: 80, null: false
    t.string "city", limit: 100, null: false
    t.string "district", limit: 100
    t.string "street", limit: 200, null: false
    t.string "building_number", limit: 30, null: false
    t.string "floor", limit: 30
    t.string "apartment", limit: 30
    t.string "landmark", limit: 200
    t.text "delivery_notes"
    t.string "postal_code", limit: 20
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.boolean "default", default: false, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_addresses_on_user_id"
    t.index ["user_id"], name: "index_addresses_one_active_default", unique: true, where: "((active = true) AND (\"default\" = true))"
    t.check_constraint "latitude IS NULL OR latitude >= '-90'::integer::numeric AND latitude <= 90::numeric", name: "addresses_latitude_range"
    t.check_constraint "longitude IS NULL OR longitude >= '-180'::integer::numeric AND longitude <= 180::numeric", name: "addresses_longitude_range"
  end

  create_table "admin_audit_events", force: :cascade do |t|
    t.bigint "actor_id", null: false
    t.string "auditable_type", null: false
    t.bigint "auditable_id", null: false
    t.string "action", null: false
    t.jsonb "change_data", default: {}, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["actor_id"], name: "index_admin_audit_events_on_actor_id"
    t.index ["auditable_type", "auditable_id", "created_at"], name: "index_admin_audits_on_subject_and_created_at"
    t.index ["auditable_type", "auditable_id"], name: "index_admin_audit_events_on_auditable"
  end

  create_table "brands", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.boolean "active", default: true, null: false
    t.string "website_url"
    t.integer "lock_version", default: 0, null: false
    t.index ["active"], name: "index_brands_on_active"
    t.index ["name"], name: "index_brands_on_name", unique: true
    t.index ["slug"], name: "index_brands_on_slug", unique: true
  end

  create_table "cart_items", force: :cascade do |t|
    t.bigint "cart_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cart_id", "product_id"], name: "index_cart_items_on_cart_id_and_product_id", unique: true
    t.index ["cart_id"], name: "index_cart_items_on_cart_id"
    t.index ["product_id"], name: "index_cart_items_on_product_id"
    t.check_constraint "quantity <= 10", name: "cart_items_quantity_maximum"
    t.check_constraint "quantity > 0", name: "cart_items_quantity_positive"
  end

  create_table "carts", force: :cascade do |t|
    t.bigint "user_id"
    t.string "guest_token"
    t.integer "status", default: 0, null: false
    t.string "currency", default: "EGP", null: false
    t.datetime "browser_imported_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "checkout_submission_token"
    t.bigint "applied_coupon_id"
    t.string "applied_coupon_code_snapshot"
    t.index ["applied_coupon_id"], name: "index_carts_on_applied_coupon_id"
    t.index ["checkout_submission_token"], name: "index_carts_on_checkout_submission_token", unique: true
    t.index ["guest_token"], name: "index_carts_on_guest_token", unique: true, where: "(guest_token IS NOT NULL)"
    t.index ["user_id"], name: "index_carts_on_user_id"
    t.index ["user_id"], name: "index_one_active_cart_per_user", unique: true, where: "((status = 0) AND (user_id IS NOT NULL))"
    t.check_constraint "(user_id IS NOT NULL) <> (guest_token IS NOT NULL)", name: "carts_exactly_one_owner"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2, 3, 4])", name: "carts_status_valid"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.string "icon"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", default: true, null: false
    t.integer "position", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.index ["active", "position"], name: "index_categories_on_active_and_position"
    t.index ["name"], name: "index_categories_on_name", unique: true
    t.index ["slug"], name: "index_categories_on_slug", unique: true
    t.check_constraint "\"position\" >= 0", name: "categories_position_nonnegative"
  end

  create_table "coupons", force: :cascade do |t|
    t.bigint "promotion_id", null: false
    t.string "code", null: false
    t.string "normalized_code", null: false
    t.boolean "active", default: true, null: false
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.integer "total_usage_limit"
    t.integer "per_customer_usage_limit"
    t.integer "minimum_subtotal_cents"
    t.integer "maximum_discount_cents"
    t.boolean "first_order_only"
    t.boolean "authenticated_only"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((normalized_code)::text)", name: "index_coupons_on_lower_normalized_code", unique: true
    t.index ["promotion_id"], name: "index_coupons_on_promotion_id"
    t.check_constraint "per_customer_usage_limit IS NULL OR per_customer_usage_limit > 0", name: "coupons_customer_limit_positive"
    t.check_constraint "total_usage_limit IS NULL OR total_usage_limit > 0", name: "coupons_total_limit_positive"
  end

  create_table "delivery_methods", force: :cascade do |t|
    t.bigint "delivery_zone_id", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.integer "additional_fee_cents", default: 0, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["delivery_zone_id", "code"], name: "index_delivery_methods_on_delivery_zone_id_and_code", unique: true
    t.index ["delivery_zone_id"], name: "index_delivery_methods_on_delivery_zone_id"
    t.check_constraint "additional_fee_cents >= 0 AND \"position\" >= 0", name: "delivery_methods_values_valid"
  end

  create_table "delivery_slots", force: :cascade do |t|
    t.bigint "delivery_zone_id", null: false
    t.date "delivery_date", null: false
    t.time "starts_at", null: false
    t.time "ends_at", null: false
    t.integer "capacity", null: false
    t.integer "booked_count", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["delivery_zone_id", "delivery_date", "starts_at"], name: "index_delivery_slots_unique_window", unique: true
    t.index ["delivery_zone_id"], name: "index_delivery_slots_on_delivery_zone_id"
    t.check_constraint "capacity > 0 AND booked_count >= 0 AND booked_count <= capacity", name: "delivery_slots_capacity_valid"
    t.check_constraint "ends_at > starts_at", name: "delivery_slots_window_valid"
  end

  create_table "delivery_zone_districts", force: :cascade do |t|
    t.bigint "delivery_zone_id", null: false
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["delivery_zone_id", "normalized_name"], name: "index_zone_districts_on_zone_and_normalized_name", unique: true
    t.index ["delivery_zone_id"], name: "index_delivery_zone_districts_on_delivery_zone_id"
    t.index ["normalized_name"], name: "index_delivery_zone_districts_on_normalized_name"
  end

  create_table "delivery_zones", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.string "governorate", null: false
    t.string "city", null: false
    t.boolean "active", default: true, null: false
    t.integer "delivery_fee_cents", default: 0, null: false
    t.integer "free_delivery_threshold_cents"
    t.integer "minimum_order_cents"
    t.integer "estimated_min_minutes", null: false
    t.integer "estimated_max_minutes", null: false
    t.boolean "same_day_available", default: false, null: false
    t.boolean "scheduled_delivery_available", default: true, null: false
    t.boolean "cash_on_delivery_available", default: true, null: false
    t.integer "position", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "position"], name: "index_delivery_zones_on_active_and_position"
    t.index ["code"], name: "index_delivery_zones_on_code", unique: true
    t.index ["governorate", "city", "name"], name: "index_delivery_zones_on_governorate_and_city_and_name", unique: true
    t.check_constraint "\"position\" >= 0", name: "delivery_zones_position_nonnegative"
    t.check_constraint "delivery_fee_cents >= 0 AND (free_delivery_threshold_cents IS NULL OR free_delivery_threshold_cents >= 0) AND (minimum_order_cents IS NULL OR minimum_order_cents >= 0)", name: "delivery_zones_money_nonnegative"
    t.check_constraint "estimated_min_minutes > 0 AND estimated_max_minutes >= estimated_min_minutes", name: "delivery_zones_estimate_valid"
  end

  create_table "fulfilments", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "delivery_zone_id"
    t.bigint "delivery_slot_id"
    t.bigint "assigned_to_id"
    t.bigint "assigned_by_id"
    t.integer "status", default: 0, null: false
    t.datetime "assigned_at"
    t.datetime "picked_at"
    t.datetime "dispatched_at"
    t.datetime "delivered_at"
    t.text "internal_notes"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_by_id"], name: "index_fulfilments_on_assigned_by_id"
    t.index ["assigned_to_id"], name: "index_fulfilments_on_assigned_to_id"
    t.index ["delivery_slot_id"], name: "index_fulfilments_on_delivery_slot_id"
    t.index ["delivery_zone_id"], name: "index_fulfilments_on_delivery_zone_id"
    t.index ["order_id"], name: "index_fulfilments_on_order_id", unique: true
    t.index ["status", "created_at"], name: "index_fulfilments_on_status_and_created_at"
    t.index ["status", "created_at"], name: "index_fulfilments_reporting_status_created"
    t.check_constraint "status >= 0 AND status <= 5", name: "fulfilments_status_valid"
  end

  create_table "inventory_movements", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "actor_id"
    t.integer "movement_type", null: false
    t.integer "quantity_delta", null: false
    t.integer "quantity_before", null: false
    t.integer "quantity_after", null: false
    t.text "reason", null: false
    t.string "reference_type"
    t.bigint "reference_id"
    t.jsonb "metadata", default: {}, null: false
    t.string "idempotency_key"
    t.datetime "created_at", null: false
    t.index ["actor_id"], name: "index_inventory_movements_on_actor_id"
    t.index ["idempotency_key"], name: "index_inventory_movements_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["movement_type", "created_at"], name: "index_inventory_movements_reporting_type_time"
    t.index ["product_id", "created_at"], name: "index_inventory_movements_on_product_id_and_created_at"
    t.index ["product_id"], name: "index_inventory_movements_on_product_id"
    t.index ["reference_type", "reference_id"], name: "index_inventory_movements_on_reference"
    t.check_constraint "quantity_before >= 0 AND quantity_after >= 0", name: "inventory_movements_quantities_nonnegative"
    t.check_constraint "quantity_delta <> 0", name: "inventory_movements_delta_nonzero"
  end

  create_table "inventory_reservations", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "order_item_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", null: false
    t.integer "status", default: 0, null: false
    t.datetime "expires_at"
    t.datetime "released_at"
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_inventory_reservations_on_order_id"
    t.index ["order_item_id"], name: "index_inventory_reservations_on_order_item_id", unique: true
    t.index ["product_id", "status"], name: "index_inventory_reservations_on_product_id_and_status"
    t.index ["product_id"], name: "index_inventory_reservations_on_product_id"
    t.index ["status", "product_id"], name: "index_inventory_reservations_reporting_status_product"
    t.check_constraint "quantity > 0", name: "inventory_reservations_quantity_positive"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2])", name: "inventory_reservations_status_valid"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "actor_id"
    t.string "notifiable_type", null: false
    t.bigint "notifiable_id", null: false
    t.string "kind", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.datetime "read_at"
    t.jsonb "metadata", default: {}, null: false
    t.string "deduplication_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["deduplication_key"], name: "index_notifications_on_deduplication_key", unique: true, where: "(deduplication_key IS NOT NULL)"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "order_addresses", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.string "label", null: false
    t.string "recipient_name", null: false
    t.string "mobile_number", null: false
    t.string "governorate", null: false
    t.string "city", null: false
    t.string "district"
    t.string "street", null: false
    t.string "building_number", null: false
    t.string "floor"
    t.string "apartment"
    t.string "landmark"
    t.string "postal_code"
    t.text "delivery_notes"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_addresses_on_order_id", unique: true
  end

  create_table "order_events", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "actor_id"
    t.string "event_type", null: false
    t.string "from_status"
    t.string "to_status"
    t.jsonb "metadata", default: {}, null: false
    t.boolean "customer_visible", default: false, null: false
    t.datetime "created_at", null: false
    t.index ["actor_id"], name: "index_order_events_on_actor_id"
    t.index ["event_type", "created_at"], name: "index_order_events_reporting_type_time"
    t.index ["event_type"], name: "index_order_events_on_event_type"
    t.index ["order_id", "created_at"], name: "index_order_events_on_order_id_and_created_at"
    t.index ["order_id"], name: "index_order_events_on_order_id"
    t.check_constraint "event_type::text = ANY (ARRAY['order_submitted'::character varying, 'prescription_review_started'::character varying, 'prescription_approved'::character varying, 'prescription_partially_approved'::character varying, 'prescription_rejected'::character varying, 'order_confirmed'::character varying, 'preparation_started'::character varying, 'order_ready'::character varying, 'out_for_delivery'::character varying, 'delivered'::character varying, 'cancelled'::character varying, 'rejected'::character varying, 'reservations_released'::character varying, 'reservations_consumed'::character varying, 'follow_up_opened'::character varying, 'customer_responded'::character varying, 'follow_up_resolved'::character varying, 'customer_cancelled'::character varying, 'staff_cancelled'::character varying, 'system_cancelled'::character varying, 'reservations_extended'::character varying, 'reservations_expired'::character varying, 'notification_sent'::character varying, 'fulfilment_assigned'::character varying, 'delivery_scheduled'::character varying, 'fulfilment_picking'::character varying, 'fulfilment_packed'::character varying, 'delivery_dispatched'::character varying, 'delivery_completed'::character varying]::text[])", name: "order_events_type_valid"
  end

  create_table "order_follow_up_messages", force: :cascade do |t|
    t.bigint "order_follow_up_id", null: false
    t.bigint "author_id", null: false
    t.string "author_role", null: false
    t.text "body", null: false
    t.boolean "customer_visible", default: true, null: false
    t.datetime "created_at", null: false
    t.index ["author_id"], name: "index_order_follow_up_messages_on_author_id"
    t.index ["order_follow_up_id"], name: "index_order_follow_up_messages_on_order_follow_up_id"
  end

  create_table "order_follow_ups", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "prescription_id"
    t.bigint "opened_by_id", null: false
    t.bigint "resolved_by_id"
    t.integer "kind", null: false
    t.integer "status", default: 1, null: false
    t.string "subject", null: false
    t.text "customer_message", null: false
    t.text "internal_notes"
    t.boolean "response_required", default: true, null: false
    t.datetime "responded_at"
    t.datetime "resolved_at"
    t.datetime "due_at"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["opened_by_id"], name: "index_order_follow_ups_on_opened_by_id"
    t.index ["order_id"], name: "index_order_follow_ups_on_order_id"
    t.index ["prescription_id"], name: "index_order_follow_ups_on_prescription_id"
    t.index ["resolved_by_id"], name: "index_order_follow_ups_on_resolved_by_id"
    t.index ["status", "due_at"], name: "index_order_follow_ups_on_status_and_due_at"
    t.check_constraint "kind >= 0 AND kind <= 5", name: "follow_ups_kind_valid"
    t.check_constraint "status >= 0 AND status <= 4", name: "follow_ups_status_valid"
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "product_id"
    t.string "product_name", null: false
    t.string "product_slug", null: false
    t.string "brand_name", null: false
    t.string "category_name", null: false
    t.integer "unit_price_cents", null: false
    t.integer "compare_at_price_cents"
    t.integer "discount_cents", default: 0, null: false
    t.integer "quantity", null: false
    t.integer "line_total_cents", null: false
    t.boolean "requires_prescription", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "original_unit_price_cents"
    t.integer "final_unit_price_cents"
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_id", "order_id"], name: "index_order_items_reporting_product_order"
    t.index ["product_id"], name: "index_order_items_on_product_id"
    t.check_constraint "quantity > 0", name: "order_items_quantity_positive"
    t.check_constraint "unit_price_cents >= 0 AND discount_cents >= 0 AND line_total_cents >= 0", name: "order_items_money_nonnegative"
  end

  create_table "order_promotions", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "promotion_id"
    t.bigint "coupon_id"
    t.string "promotion_name", null: false
    t.string "code"
    t.string "promotion_type", null: false
    t.string "discount_type", null: false
    t.integer "discount_value_snapshot", null: false
    t.integer "discount_cents", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["coupon_id"], name: "index_order_promotions_on_coupon_id"
    t.index ["order_id", "promotion_id"], name: "index_order_promotions_on_order_id_and_promotion_id", unique: true
    t.index ["order_id"], name: "index_order_promotions_on_order_id"
    t.index ["promotion_id"], name: "index_order_promotions_on_promotion_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "cart_id", null: false
    t.string "number", null: false
    t.integer "status", null: false
    t.integer "payment_method", null: false
    t.integer "payment_status", default: 0, null: false
    t.string "currency", default: "EGP", null: false
    t.integer "subtotal_cents", default: 0, null: false
    t.integer "discount_cents", default: 0, null: false
    t.integer "delivery_fee_cents", default: 0, null: false
    t.integer "total_cents", default: 0, null: false
    t.string "customer_email", null: false
    t.string "customer_mobile_number", null: false
    t.string "customer_first_name", null: false
    t.string "customer_last_name", null: false
    t.integer "delivery_method", null: false
    t.text "delivery_notes"
    t.boolean "prescription_required", default: false, null: false
    t.datetime "submitted_at", null: false
    t.datetime "confirmed_at"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "cancelled_by_id"
    t.text "cancellation_reason"
    t.integer "cancellation_source"
    t.bigint "delivery_zone_id"
    t.bigint "delivery_slot_id"
    t.string "delivery_zone_code"
    t.string "delivery_zone_name"
    t.string "delivery_method_name"
    t.integer "delivery_estimated_min_minutes"
    t.integer "delivery_estimated_max_minutes"
    t.datetime "scheduled_for"
    t.integer "product_discount_cents", default: 0, null: false
    t.integer "cart_discount_cents", default: 0, null: false
    t.integer "delivery_discount_cents", default: 0, null: false
    t.string "pricing_calculation_version", default: "v1", null: false
    t.index ["cancelled_by_id"], name: "index_orders_on_cancelled_by_id"
    t.index ["cart_id"], name: "index_orders_on_cart_id", unique: true
    t.index ["delivery_slot_id"], name: "index_orders_on_delivery_slot_id"
    t.index ["delivery_zone_id"], name: "index_orders_on_delivery_zone_id"
    t.index ["number"], name: "index_orders_on_number", unique: true
    t.index ["status", "submitted_at"], name: "index_orders_reporting_status_submitted"
    t.index ["user_id", "submitted_at"], name: "index_orders_on_user_id_and_submitted_at"
    t.index ["user_id", "submitted_at"], name: "index_orders_reporting_user_submitted"
    t.index ["user_id"], name: "index_orders_on_user_id"
    t.check_constraint "currency::text = 'EGP'::text", name: "orders_currency_valid"
    t.check_constraint "delivery_method = ANY (ARRAY[0, 1, 2])", name: "orders_delivery_method_valid"
    t.check_constraint "payment_method = ANY (ARRAY[0, 1, 2])", name: "orders_payment_method_valid"
    t.check_constraint "payment_status = ANY (ARRAY[0, 1, 2, 3, 4])", name: "orders_payment_status_valid"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2, 3, 4, 5, 6, 7, 8])", name: "orders_status_valid"
    t.check_constraint "subtotal_cents >= 0 AND discount_cents >= 0 AND delivery_fee_cents >= 0 AND total_cents >= 0", name: "orders_money_nonnegative"
  end

  create_table "prescriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "order_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "submitted_at", null: false
    t.datetime "reviewed_at"
    t.bigint "reviewed_by_id"
    t.text "rejection_reason"
    t.text "customer_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.text "customer_message"
    t.text "internal_notes"
    t.index ["order_id"], name: "index_prescriptions_on_order_id", unique: true
    t.index ["reviewed_by_id"], name: "index_prescriptions_on_reviewed_by_id"
    t.index ["status", "submitted_at"], name: "index_prescriptions_reporting_status_submitted"
    t.index ["user_id"], name: "index_prescriptions_on_user_id"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2, 3, 4])", name: "prescriptions_status_valid"
  end

  create_table "product_images", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.integer "position", default: 0, null: false
    t.string "alt_text", null: false
    t.boolean "primary", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "position"], name: "index_product_images_on_product_id_and_position", unique: true
    t.index ["product_id"], name: "index_one_primary_image_per_product", unique: true, where: "(\"primary\" = true)"
    t.index ["product_id"], name: "index_product_images_on_product_id"
    t.check_constraint "\"position\" >= 0", name: "product_images_position_nonnegative"
  end

  create_table "product_price_changes", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "changed_by_id", null: false
    t.integer "old_price_cents", null: false
    t.integer "new_price_cents", null: false
    t.integer "old_compare_at_price_cents"
    t.integer "new_compare_at_price_cents"
    t.integer "old_cost_price_cents"
    t.integer "new_cost_price_cents"
    t.text "reason", null: false
    t.integer "source", default: 0, null: false
    t.datetime "effective_at", null: false
    t.datetime "created_at", null: false
    t.index ["changed_by_id"], name: "index_product_price_changes_on_changed_by_id"
    t.index ["product_id", "effective_at"], name: "index_product_price_changes_on_product_id_and_effective_at"
    t.index ["product_id"], name: "index_product_price_changes_on_product_id"
    t.check_constraint "old_price_cents >= 0 AND new_price_cents >= 0", name: "price_changes_prices_nonnegative"
  end

  create_table "products", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "short_description"
    t.text "description"
    t.decimal "price", precision: 10, scale: 2, null: false
    t.decimal "compare_at_price", precision: 10, scale: 2
    t.integer "stock_quantity", default: 0, null: false
    t.boolean "featured", default: false, null: false
    t.boolean "requires_prescription", default: false, null: false
    t.boolean "active", default: true, null: false
    t.bigint "category_id", null: false
    t.bigint "brand_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "active_ingredient"
    t.string "dosage_form"
    t.string "strength"
    t.string "manufacturer"
    t.string "sku"
    t.string "barcode"
    t.decimal "cost_price", precision: 10, scale: 2
    t.integer "low_stock_threshold", default: 5, null: false
    t.integer "maximum_order_quantity", default: 10, null: false
    t.boolean "pharmacist_review_required", default: false, null: false
    t.boolean "cold_chain_required", default: false, null: false
    t.datetime "published_at"
    t.datetime "discontinued_at"
    t.integer "lock_version", default: 0, null: false
    t.index ["active", "low_stock_threshold"], name: "index_products_on_active_and_low_stock_threshold"
    t.index ["active"], name: "index_products_on_active"
    t.index ["barcode"], name: "index_products_on_barcode", unique: true, where: "(barcode IS NOT NULL)"
    t.index ["brand_id"], name: "index_products_on_brand_id"
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["featured"], name: "index_products_on_featured"
    t.index ["sku"], name: "index_products_on_sku", unique: true, where: "(sku IS NOT NULL)"
    t.index ["slug"], name: "index_products_on_slug", unique: true
    t.check_constraint "compare_at_price IS NULL OR compare_at_price >= 0::numeric", name: "products_compare_at_price_non_negative"
    t.check_constraint "cost_price IS NULL OR cost_price >= 0::numeric", name: "products_cost_price_nonnegative"
    t.check_constraint "low_stock_threshold >= 0", name: "products_low_stock_threshold_nonnegative"
    t.check_constraint "maximum_order_quantity > 0", name: "products_maximum_order_quantity_positive"
    t.check_constraint "price >= 0::numeric", name: "products_price_non_negative"
    t.check_constraint "stock_quantity >= 0", name: "products_stock_nonnegative"
    t.check_constraint "stock_quantity >= 0", name: "products_stock_quantity_non_negative"
  end

  create_table "promotion_audit_events", force: :cascade do |t|
    t.bigint "promotion_id", null: false
    t.bigint "actor_id", null: false
    t.string "action", null: false
    t.jsonb "changes", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_promotion_audit_events_on_actor_id"
    t.index ["promotion_id"], name: "index_promotion_audit_events_on_promotion_id"
  end

  create_table "promotion_brands", force: :cascade do |t|
    t.bigint "promotion_id", null: false
    t.bigint "brand_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id"], name: "index_promotion_brands_on_brand_id"
    t.index ["promotion_id", "brand_id"], name: "index_promotion_brands_unique", unique: true
    t.index ["promotion_id"], name: "index_promotion_brands_on_promotion_id"
  end

  create_table "promotion_categories", force: :cascade do |t|
    t.bigint "promotion_id", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_promotion_categories_on_category_id"
    t.index ["promotion_id", "category_id"], name: "index_promotion_categories_unique", unique: true
    t.index ["promotion_id"], name: "index_promotion_categories_on_promotion_id"
  end

  create_table "promotion_exclusions", force: :cascade do |t|
    t.bigint "promotion_id", null: false
    t.bigint "product_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_promotion_exclusions_on_product_id"
    t.index ["promotion_id", "product_id"], name: "index_promotion_exclusions_on_promotion_id_and_product_id", unique: true
    t.index ["promotion_id"], name: "index_promotion_exclusions_on_promotion_id"
  end

  create_table "promotion_products", force: :cascade do |t|
    t.bigint "promotion_id", null: false
    t.bigint "product_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_promotion_products_on_product_id"
    t.index ["promotion_id", "product_id"], name: "index_promotion_products_unique", unique: true
    t.index ["promotion_id"], name: "index_promotion_products_on_promotion_id"
  end

  create_table "promotion_redemptions", force: :cascade do |t|
    t.bigint "promotion_id", null: false
    t.bigint "coupon_id"
    t.bigint "user_id", null: false
    t.bigint "order_id", null: false
    t.string "code_snapshot"
    t.integer "discount_cents", null: false
    t.string "status", default: "redeemed", null: false
    t.datetime "redeemed_at", null: false
    t.datetime "released_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["coupon_id"], name: "index_promotion_redemptions_on_coupon_id"
    t.index ["order_id"], name: "index_one_coupon_redemption_per_order", unique: true, where: "(coupon_id IS NOT NULL)"
    t.index ["order_id"], name: "index_promotion_redemptions_on_order_id"
    t.index ["promotion_id", "order_id"], name: "index_promotion_redemptions_on_promotion_id_and_order_id", unique: true
    t.index ["promotion_id"], name: "index_promotion_redemptions_on_promotion_id"
    t.index ["status", "redeemed_at"], name: "index_redemptions_reporting_status_time"
    t.index ["user_id"], name: "index_promotion_redemptions_on_user_id"
    t.check_constraint "discount_cents >= 0", name: "promotion_redemptions_discount_nonnegative"
    t.check_constraint "status::text = ANY (ARRAY['redeemed'::character varying, 'released'::character varying]::text[])", name: "promotion_redemptions_status_valid"
  end

  create_table "promotions", force: :cascade do |t|
    t.string "name", null: false
    t.string "internal_name", null: false
    t.text "description"
    t.string "promotion_type", null: false
    t.string "discount_type", null: false
    t.integer "discount_value", null: false
    t.integer "maximum_discount_cents"
    t.integer "minimum_subtotal_cents", default: 0, null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.boolean "active", default: false, null: false
    t.integer "priority", default: 0, null: false
    t.boolean "stackable", default: false, null: false
    t.boolean "automatic", default: false, null: false
    t.boolean "first_order_only", default: false, null: false
    t.boolean "authenticated_only", default: false, null: false
    t.boolean "applies_to_prescription_products", default: false, null: false
    t.integer "total_usage_limit"
    t.integer "per_customer_usage_limit"
    t.bigint "delivery_zone_id"
    t.string "delivery_method_code"
    t.jsonb "metadata", default: {}, null: false
    t.bigint "created_by_id", null: false
    t.bigint "updated_by_id", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "starts_at", "ends_at"], name: "index_promotions_on_active_and_starts_at_and_ends_at"
    t.index ["created_by_id"], name: "index_promotions_on_created_by_id"
    t.index ["delivery_zone_id"], name: "index_promotions_on_delivery_zone_id"
    t.index ["updated_by_id"], name: "index_promotions_on_updated_by_id"
    t.check_constraint "discount_type::text = ANY (ARRAY['percentage'::character varying, 'fixed_amount'::character varying, 'fixed_price'::character varying, 'free_delivery'::character varying]::text[])", name: "promotions_discount_type_valid"
    t.check_constraint "discount_value >= 0 AND minimum_subtotal_cents >= 0 AND priority >= 0", name: "promotions_values_nonnegative"
    t.check_constraint "ends_at > starts_at", name: "promotions_time_range_valid"
    t.check_constraint "per_customer_usage_limit IS NULL OR per_customer_usage_limit > 0", name: "promotions_customer_limit_positive"
    t.check_constraint "promotion_type::text = ANY (ARRAY['product'::character varying, 'category'::character varying, 'brand'::character varying, 'cart'::character varying, 'delivery'::character varying]::text[])", name: "promotions_type_valid"
    t.check_constraint "total_usage_limit IS NULL OR total_usage_limit > 0", name: "promotions_total_limit_positive"
  end

  create_table "report_export_events", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "report_type", null: false
    t.string "format", default: "csv", null: false
    t.datetime "range_start", null: false
    t.datetime "range_end", null: false
    t.jsonb "filters", default: {}, null: false
    t.integer "row_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "created_at"], name: "index_report_export_events_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_report_export_events_on_user_id"
    t.check_constraint "format::text = 'csv'::text", name: "report_export_events_format_valid"
    t.check_constraint "range_end > range_start AND row_count >= 0", name: "report_export_events_range_rows_valid"
    t.check_constraint "report_type::text = ANY (ARRAY['sales'::character varying, 'orders'::character varying, 'products'::character varying, 'inventory'::character varying, 'promotions'::character varying, 'customers'::character varying, 'prescriptions'::character varying, 'fulfilments'::character varying]::text[])", name: "report_export_events_type_valid"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "mobile_number", null: false
    t.integer "role", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.check_constraint "role = ANY (ARRAY[0, 1, 2, 3, 4])", name: "users_role_valid"
  end

  create_table "wishlist_items", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "product_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_wishlist_items_on_product_id"
    t.index ["user_id", "product_id"], name: "index_wishlist_items_on_user_id_and_product_id", unique: true
    t.index ["user_id"], name: "index_wishlist_items_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "addresses", "users", on_delete: :cascade
  add_foreign_key "admin_audit_events", "users", column: "actor_id"
  add_foreign_key "cart_items", "carts", on_delete: :cascade
  add_foreign_key "cart_items", "products"
  add_foreign_key "carts", "coupons", column: "applied_coupon_id"
  add_foreign_key "carts", "users"
  add_foreign_key "coupons", "promotions"
  add_foreign_key "delivery_methods", "delivery_zones"
  add_foreign_key "delivery_slots", "delivery_zones"
  add_foreign_key "delivery_zone_districts", "delivery_zones"
  add_foreign_key "fulfilments", "delivery_slots"
  add_foreign_key "fulfilments", "delivery_zones"
  add_foreign_key "fulfilments", "orders"
  add_foreign_key "fulfilments", "users", column: "assigned_by_id"
  add_foreign_key "fulfilments", "users", column: "assigned_to_id"
  add_foreign_key "inventory_movements", "products"
  add_foreign_key "inventory_movements", "users", column: "actor_id"
  add_foreign_key "inventory_reservations", "order_items", on_delete: :cascade
  add_foreign_key "inventory_reservations", "orders", on_delete: :cascade
  add_foreign_key "inventory_reservations", "products"
  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "order_addresses", "orders", on_delete: :cascade
  add_foreign_key "order_events", "orders", on_delete: :cascade
  add_foreign_key "order_events", "users", column: "actor_id"
  add_foreign_key "order_follow_up_messages", "order_follow_ups"
  add_foreign_key "order_follow_up_messages", "users", column: "author_id"
  add_foreign_key "order_follow_ups", "orders"
  add_foreign_key "order_follow_ups", "prescriptions"
  add_foreign_key "order_follow_ups", "users", column: "opened_by_id"
  add_foreign_key "order_follow_ups", "users", column: "resolved_by_id"
  add_foreign_key "order_items", "orders", on_delete: :cascade
  add_foreign_key "order_items", "products", on_delete: :nullify
  add_foreign_key "order_promotions", "coupons"
  add_foreign_key "order_promotions", "orders"
  add_foreign_key "order_promotions", "promotions"
  add_foreign_key "orders", "carts"
  add_foreign_key "orders", "delivery_slots"
  add_foreign_key "orders", "delivery_zones"
  add_foreign_key "orders", "users"
  add_foreign_key "orders", "users", column: "cancelled_by_id"
  add_foreign_key "prescriptions", "orders", on_delete: :cascade
  add_foreign_key "prescriptions", "users"
  add_foreign_key "prescriptions", "users", column: "reviewed_by_id"
  add_foreign_key "product_images", "products"
  add_foreign_key "product_price_changes", "products"
  add_foreign_key "product_price_changes", "users", column: "changed_by_id"
  add_foreign_key "products", "brands"
  add_foreign_key "products", "categories"
  add_foreign_key "promotion_audit_events", "promotions"
  add_foreign_key "promotion_audit_events", "users", column: "actor_id"
  add_foreign_key "promotion_brands", "brands"
  add_foreign_key "promotion_brands", "promotions"
  add_foreign_key "promotion_categories", "categories"
  add_foreign_key "promotion_categories", "promotions"
  add_foreign_key "promotion_exclusions", "products"
  add_foreign_key "promotion_exclusions", "promotions"
  add_foreign_key "promotion_products", "products"
  add_foreign_key "promotion_products", "promotions"
  add_foreign_key "promotion_redemptions", "coupons"
  add_foreign_key "promotion_redemptions", "orders"
  add_foreign_key "promotion_redemptions", "promotions"
  add_foreign_key "promotion_redemptions", "users"
  add_foreign_key "promotions", "delivery_zones"
  add_foreign_key "promotions", "users", column: "created_by_id"
  add_foreign_key "promotions", "users", column: "updated_by_id"
  add_foreign_key "report_export_events", "users"
  add_foreign_key "wishlist_items", "products", on_delete: :cascade
  add_foreign_key "wishlist_items", "users", on_delete: :cascade
end
