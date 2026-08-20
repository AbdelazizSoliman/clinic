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

ActiveRecord::Schema[8.1].define(version: 2026_08_18_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "active_ingredients", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.text "notes"
    t.string "search_name"
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_active_ingredients_on_active"
    t.index ["code"], name: "index_active_ingredients_on_code", unique: true
    t.index ["normalized_name"], name: "index_active_ingredients_on_normalized_name", unique: true
    t.index ["search_name"], name: "index_active_ingredients_on_search_name_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "addresses", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "apartment", limit: 30
    t.string "building_number", limit: 30, null: false
    t.string "city", limit: 100, null: false
    t.datetime "created_at", null: false
    t.boolean "default", default: false, null: false
    t.text "delivery_notes"
    t.string "district", limit: 100
    t.string "floor", limit: 30
    t.string "governorate", limit: 80, null: false
    t.string "label", limit: 50, null: false
    t.string "landmark", limit: 200
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.string "mobile_number", limit: 20, null: false
    t.string "postal_code", limit: 20
    t.string "recipient_name", limit: 120, null: false
    t.string "street", limit: 200, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_addresses_on_user_id"
    t.index ["user_id"], name: "index_addresses_one_active_default", unique: true, where: "((active = true) AND (\"default\" = true))"
    t.check_constraint "latitude IS NULL OR latitude >= '-90'::integer::numeric AND latitude <= 90::numeric", name: "addresses_latitude_range"
    t.check_constraint "longitude IS NULL OR longitude >= '-180'::integer::numeric AND longitude <= 180::numeric", name: "addresses_longitude_range"
  end

  create_table "admin_audit_events", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "actor_id", null: false
    t.bigint "auditable_id", null: false
    t.string "auditable_type", null: false
    t.jsonb "change_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.index ["actor_id"], name: "index_admin_audit_events_on_actor_id"
    t.index ["auditable_type", "auditable_id", "created_at"], name: "index_admin_audits_on_subject_and_created_at"
    t.index ["auditable_type", "auditable_id"], name: "index_admin_audit_events_on_auditable"
  end

  create_table "brands", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.string "search_name"
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.string "website_url"
    t.index ["active"], name: "index_brands_on_active"
    t.index ["name"], name: "index_brands_on_name", unique: true
    t.index ["search_name"], name: "index_brands_on_search_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["slug"], name: "index_brands_on_slug", unique: true
  end

  create_table "cart_items", force: :cascade do |t|
    t.bigint "cart_id", null: false
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", null: false
    t.datetime "updated_at", null: false
    t.index ["cart_id", "product_id"], name: "index_cart_items_on_cart_id_and_product_id", unique: true
    t.index ["cart_id"], name: "index_cart_items_on_cart_id"
    t.index ["product_id"], name: "index_cart_items_on_product_id"
    t.check_constraint "quantity <= 10", name: "cart_items_quantity_maximum"
    t.check_constraint "quantity > 0", name: "cart_items_quantity_positive"
  end

  create_table "carts", force: :cascade do |t|
    t.string "applied_coupon_code_snapshot"
    t.bigint "applied_coupon_id"
    t.datetime "browser_imported_at"
    t.string "checkout_submission_token"
    t.datetime "created_at", null: false
    t.string "currency", default: "EGP", null: false
    t.string "guest_token"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["applied_coupon_id"], name: "index_carts_on_applied_coupon_id"
    t.index ["checkout_submission_token"], name: "index_carts_on_checkout_submission_token", unique: true
    t.index ["guest_token"], name: "index_carts_on_guest_token", unique: true, where: "(guest_token IS NOT NULL)"
    t.index ["user_id"], name: "index_carts_on_user_id"
    t.index ["user_id"], name: "index_one_active_cart_per_user", unique: true, where: "((status = 0) AND (user_id IS NOT NULL))"
    t.check_constraint "(user_id IS NOT NULL) <> (guest_token IS NOT NULL)", name: "carts_exactly_one_owner"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2, 3, 4])", name: "carts_status_valid"
  end

  create_table "cashier_sessions", force: :cascade do |t|
    t.bigint "cash_difference_cents"
    t.datetime "closed_at"
    t.bigint "closing_cash_counted_cents"
    t.datetime "created_at", null: false
    t.bigint "expected_cash_cents"
    t.string "identifier", null: false
    t.integer "lock_version", default: 0, null: false
    t.text "notes"
    t.datetime "opened_at", null: false
    t.bigint "opening_cash_cents", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["identifier"], name: "index_cashier_sessions_on_identifier", unique: true
    t.index ["user_id"], name: "index_cashier_sessions_on_user_id"
    t.index ["user_id"], name: "index_cashier_sessions_one_open_per_user", unique: true, where: "(status = 0)"
    t.check_constraint "opening_cash_cents >= 0", name: "cashier_sessions_opening_cash_nonnegative"
    t.check_constraint "status = 0 AND closed_at IS NULL AND expected_cash_cents IS NULL AND closing_cash_counted_cents IS NULL AND cash_difference_cents IS NULL OR status = 1 AND closed_at IS NOT NULL AND expected_cash_cents >= 0 AND closing_cash_counted_cents >= 0 AND cash_difference_cents = (closing_cash_counted_cents - expected_cash_cents)", name: "cashier_sessions_close_consistent"
    t.check_constraint "status = ANY (ARRAY[0, 1])", name: "cashier_sessions_status_valid"
  end

  create_table "categories", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "icon"
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.string "search_name"
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "position"], name: "index_categories_on_active_and_position"
    t.index ["name"], name: "index_categories_on_name", unique: true
    t.index ["search_name"], name: "index_categories_on_search_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["slug"], name: "index_categories_on_slug", unique: true
    t.check_constraint "\"position\" >= 0", name: "categories_position_nonnegative"
  end

  create_table "coupons", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "authenticated_only"
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "ends_at"
    t.boolean "first_order_only"
    t.integer "lock_version", default: 0, null: false
    t.integer "maximum_discount_cents"
    t.integer "minimum_subtotal_cents"
    t.string "normalized_code", null: false
    t.integer "per_customer_usage_limit"
    t.bigint "promotion_id", null: false
    t.datetime "starts_at"
    t.integer "total_usage_limit"
    t.datetime "updated_at", null: false
    t.index "lower((normalized_code)::text)", name: "index_coupons_on_lower_normalized_code", unique: true
    t.index ["promotion_id"], name: "index_coupons_on_promotion_id"
    t.check_constraint "per_customer_usage_limit IS NULL OR per_customer_usage_limit > 0", name: "coupons_customer_limit_positive"
    t.check_constraint "total_usage_limit IS NULL OR total_usage_limit > 0", name: "coupons_total_limit_positive"
  end

  create_table "delivery_methods", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "additional_fee_cents", default: 0, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.bigint "delivery_zone_id", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["delivery_zone_id", "code"], name: "index_delivery_methods_on_delivery_zone_id_and_code", unique: true
    t.index ["delivery_zone_id"], name: "index_delivery_methods_on_delivery_zone_id"
    t.check_constraint "additional_fee_cents >= 0 AND \"position\" >= 0", name: "delivery_methods_values_valid"
  end

  create_table "delivery_slots", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "booked_count", default: 0, null: false
    t.integer "capacity", null: false
    t.datetime "created_at", null: false
    t.date "delivery_date", null: false
    t.bigint "delivery_zone_id", null: false
    t.time "ends_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.time "starts_at", null: false
    t.datetime "updated_at", null: false
    t.index ["delivery_zone_id", "delivery_date", "starts_at"], name: "index_delivery_slots_unique_window", unique: true
    t.index ["delivery_zone_id"], name: "index_delivery_slots_on_delivery_zone_id"
    t.check_constraint "capacity > 0 AND booked_count >= 0 AND booked_count <= capacity", name: "delivery_slots_capacity_valid"
    t.check_constraint "ends_at > starts_at", name: "delivery_slots_window_valid"
  end

  create_table "delivery_zone_districts", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.bigint "delivery_zone_id", null: false
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.datetime "updated_at", null: false
    t.index ["delivery_zone_id", "normalized_name"], name: "index_zone_districts_on_zone_and_normalized_name", unique: true
    t.index ["delivery_zone_id"], name: "index_delivery_zone_districts_on_delivery_zone_id"
    t.index ["normalized_name"], name: "index_delivery_zone_districts_on_normalized_name"
  end

  create_table "delivery_zones", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "cash_on_delivery_available", default: true, null: false
    t.string "city", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.integer "delivery_fee_cents", default: 0, null: false
    t.integer "estimated_max_minutes", null: false
    t.integer "estimated_min_minutes", null: false
    t.integer "free_delivery_threshold_cents"
    t.string "governorate", null: false
    t.integer "lock_version", default: 0, null: false
    t.integer "minimum_order_cents"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.boolean "same_day_available", default: false, null: false
    t.boolean "scheduled_delivery_available", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["active", "position"], name: "index_delivery_zones_on_active_and_position"
    t.index ["code"], name: "index_delivery_zones_on_code", unique: true
    t.index ["governorate", "city", "name"], name: "index_delivery_zones_on_governorate_and_city_and_name", unique: true
    t.check_constraint "\"position\" >= 0", name: "delivery_zones_position_nonnegative"
    t.check_constraint "delivery_fee_cents >= 0 AND (free_delivery_threshold_cents IS NULL OR free_delivery_threshold_cents >= 0) AND (minimum_order_cents IS NULL OR minimum_order_cents >= 0)", name: "delivery_zones_money_nonnegative"
    t.check_constraint "estimated_min_minutes > 0 AND estimated_max_minutes >= estimated_min_minutes", name: "delivery_zones_estimate_valid"
  end

  create_table "drug_safety_acknowledgements", force: :cascade do |t|
    t.integer "action", null: false
    t.datetime "created_at", null: false
    t.bigint "drug_safety_finding_id", null: false
    t.bigint "pharmacist_id", null: false
    t.text "reason"
    t.index ["drug_safety_finding_id", "created_at"], name: "index_drug_safety_acknowledgements_timeline"
    t.index ["drug_safety_finding_id"], name: "index_drug_safety_acknowledgements_on_finding"
    t.index ["pharmacist_id"], name: "index_drug_safety_acknowledgements_on_pharmacist"
    t.check_constraint "action = 0 OR reason IS NOT NULL", name: "drug_safety_acknowledgements_override_reason"
    t.check_constraint "action = ANY (ARRAY[0, 1])", name: "drug_safety_acknowledgements_action_valid"
  end

  create_table "drug_safety_evaluations", force: :cascade do |t|
    t.bigint "actor_id"
    t.integer "blocking_count", default: 0, null: false
    t.string "context_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "evaluated_at", null: false
    t.integer "findings_count", default: 0, null: false
    t.bigint "prescription_review_id", null: false
    t.string "ruleset_digest", null: false
    t.integer "sequence", null: false
    t.datetime "superseded_at"
    t.integer "trigger", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_drug_safety_evaluations_on_actor_id"
    t.index ["prescription_review_id", "sequence"], name: "index_drug_safety_evaluations_unique_sequence", unique: true
    t.index ["prescription_review_id", "superseded_at"], name: "index_drug_safety_evaluations_current"
    t.index ["prescription_review_id"], name: "index_drug_safety_evaluations_on_review"
    t.check_constraint "findings_count >= 0 AND blocking_count >= 0 AND blocking_count <= findings_count", name: "drug_safety_evaluations_counts_valid"
    t.check_constraint "sequence > 0", name: "drug_safety_evaluations_sequence_positive"
    t.check_constraint "trigger >= 0 AND trigger <= 7", name: "drug_safety_evaluations_trigger_valid"
  end

  create_table "drug_safety_findings", force: :cascade do |t|
    t.boolean "blocking", default: false, null: false
    t.bigint "carried_from_id"
    t.datetime "created_at", null: false
    t.string "dedupe_key", null: false
    t.bigint "drug_safety_evaluation_id", null: false
    t.bigint "drug_safety_rule_id", null: false
    t.text "explanation", null: false
    t.integer "lock_version", default: 0, null: false
    t.jsonb "matched_facts", default: {}, null: false
    t.bigint "prescription_review_item_id", null: false
    t.bigint "related_review_item_id"
    t.datetime "resolved_at"
    t.bigint "resolved_by_id"
    t.jsonb "rule_snapshot", default: {}, null: false
    t.integer "severity", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["carried_from_id"], name: "index_drug_safety_findings_on_carried_from"
    t.index ["drug_safety_evaluation_id", "dedupe_key"], name: "index_drug_safety_findings_unique_key", unique: true
    t.index ["drug_safety_evaluation_id"], name: "index_drug_safety_findings_on_evaluation"
    t.index ["drug_safety_rule_id"], name: "index_drug_safety_findings_on_rule"
    t.index ["prescription_review_item_id"], name: "index_drug_safety_findings_on_review_item"
    t.index ["related_review_item_id"], name: "index_drug_safety_findings_on_related_item"
    t.index ["resolved_by_id"], name: "index_drug_safety_findings_on_resolved_by_id"
    t.index ["severity", "created_at"], name: "index_drug_safety_findings_on_severity_and_created_at"
    t.index ["status", "blocking"], name: "index_drug_safety_findings_on_status_and_blocking"
    t.check_constraint "NOT blocking OR severity >= 2", name: "drug_safety_findings_blocking_requires_severity"
    t.check_constraint "severity = ANY (ARRAY[0, 1, 2, 3])", name: "drug_safety_findings_severity_valid"
    t.check_constraint "status = 0 AND resolved_at IS NULL AND resolved_by_id IS NULL OR (status = ANY (ARRAY[1, 2])) AND resolved_at IS NOT NULL AND resolved_by_id IS NOT NULL OR status = 3 AND resolved_at IS NOT NULL AND resolved_by_id IS NULL", name: "drug_safety_findings_resolution_consistent"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2, 3])", name: "drug_safety_findings_status_valid"
  end

  create_table "drug_safety_rule_conditions", force: :cascade do |t|
    t.bigint "active_ingredient_id"
    t.integer "condition_type", null: false
    t.datetime "created_at", null: false
    t.bigint "drug_safety_rule_id", null: false
    t.integer "numeric_value"
    t.integer "role", default: 0, null: false
    t.string "state_key"
    t.datetime "updated_at", null: false
    t.index ["active_ingredient_id"], name: "index_rule_conditions_on_ingredient"
    t.index ["drug_safety_rule_id", "role", "condition_type"], name: "index_rule_conditions_unique_slot", unique: true
    t.index ["drug_safety_rule_id"], name: "index_rule_conditions_on_rule"
    t.check_constraint "condition_type = 0 AND active_ingredient_id IS NOT NULL AND state_key IS NULL AND numeric_value IS NULL OR condition_type = 1 AND state_key IS NOT NULL AND active_ingredient_id IS NULL AND numeric_value IS NULL OR (condition_type = ANY (ARRAY[2, 3])) AND numeric_value IS NOT NULL AND numeric_value >= 0 AND active_ingredient_id IS NULL AND state_key IS NULL", name: "drug_safety_rule_conditions_payload_valid"
    t.check_constraint "condition_type = ANY (ARRAY[0, 1, 2, 3])", name: "drug_safety_rule_conditions_type_valid"
    t.check_constraint "role = ANY (ARRAY[0, 1])", name: "drug_safety_rule_conditions_role_valid"
  end

  create_table "drug_safety_rules", force: :cascade do |t|
    t.datetime "activated_at"
    t.boolean "active", default: false, null: false
    t.string "arabic_label", null: false
    t.boolean "blocking", default: false, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.text "description", null: false
    t.datetime "effective_from"
    t.datetime "effective_to"
    t.text "evidence_note"
    t.text "internal_notes"
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.datetime "retired_at"
    t.integer "rule_type", null: false
    t.integer "severity", null: false
    t.datetime "updated_at", null: false
    t.integer "version", default: 1, null: false
    t.index ["active", "rule_type"], name: "index_drug_safety_rules_on_active_and_type"
    t.index ["code", "version"], name: "index_drug_safety_rules_unique_version", unique: true
    t.index ["code"], name: "index_drug_safety_rules_single_active_version", unique: true, where: "active"
    t.index ["created_by_id"], name: "index_drug_safety_rules_on_created_by_id"
    t.check_constraint "NOT active OR rule_type <= 6", name: "drug_safety_rules_active_type_supported"
    t.check_constraint "NOT blocking OR severity >= 2", name: "drug_safety_rules_blocking_requires_severity"
    t.check_constraint "effective_to IS NULL OR effective_from IS NULL OR effective_to > effective_from", name: "drug_safety_rules_effective_window_valid"
    t.check_constraint "rule_type >= 0 AND rule_type <= 9", name: "drug_safety_rules_type_valid"
    t.check_constraint "severity = ANY (ARRAY[0, 1, 2, 3])", name: "drug_safety_rules_severity_valid"
    t.check_constraint "version > 0", name: "drug_safety_rules_version_positive"
  end

  create_table "fulfilments", force: :cascade do |t|
    t.datetime "assigned_at"
    t.bigint "assigned_by_id"
    t.bigint "assigned_to_id"
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.bigint "delivery_slot_id"
    t.bigint "delivery_zone_id"
    t.datetime "dispatched_at"
    t.text "internal_notes"
    t.integer "lock_version", default: 0, null: false
    t.bigint "order_id", null: false
    t.datetime "picked_at"
    t.integer "status", default: 0, null: false
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

  create_table "inventory_batch_events", force: :cascade do |t|
    t.bigint "actor_id"
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.bigint "inventory_batch_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.text "reason", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_inventory_batch_events_on_actor_id"
    t.index ["inventory_batch_id", "created_at"], name: "idx_on_inventory_batch_id_created_at_27dad0d21b"
    t.index ["inventory_batch_id"], name: "index_inventory_batch_events_on_inventory_batch_id"
    t.check_constraint "event_type::text = ANY (ARRAY['created'::character varying, 'quarantined'::character varying, 'quarantine_released'::character varying, 'adjusted'::character varying]::text[])", name: "inventory_batch_events_type_valid"
  end

  create_table "inventory_batches", force: :cascade do |t|
    t.string "batch_number", null: false
    t.datetime "created_at", null: false
    t.date "expiry_date", null: false
    t.integer "lock_version", default: 0, null: false
    t.string "lot_number"
    t.date "manufacture_date"
    t.text "notes"
    t.integer "on_hand_quantity", null: false
    t.integer "original_quantity", null: false
    t.bigint "product_id", null: false
    t.bigint "purchase_receipt_id"
    t.bigint "purchase_receipt_item_id"
    t.text "quarantine_reason"
    t.datetime "quarantined_at"
    t.bigint "quarantined_by_id"
    t.datetime "received_at", null: false
    t.integer "reserved_quantity", default: 0, null: false
    t.bigint "supplier_id"
    t.integer "unit_cost_cents"
    t.datetime "updated_at", null: false
    t.index ["batch_number"], name: "index_inventory_batches_on_batch_number", unique: true
    t.index ["expiry_date", "quarantined_at"], name: "index_inventory_batches_on_expiry_date_and_quarantined_at"
    t.index ["product_id", "expiry_date", "received_at"], name: "index_inventory_batches_fefo"
    t.index ["product_id"], name: "index_inventory_batches_on_product_id"
    t.index ["purchase_receipt_id"], name: "index_inventory_batches_on_purchase_receipt_id"
    t.index ["purchase_receipt_item_id"], name: "index_inventory_batches_on_purchase_receipt_item_id"
    t.index ["quarantined_by_id"], name: "index_inventory_batches_on_quarantined_by_id"
    t.index ["supplier_id"], name: "index_inventory_batches_on_supplier_id"
    t.check_constraint "manufacture_date IS NULL OR expiry_date > manufacture_date", name: "inventory_batches_expiry_after_manufacture"
    t.check_constraint "on_hand_quantity >= 0 AND reserved_quantity >= 0 AND reserved_quantity <= on_hand_quantity", name: "inventory_batches_quantities_valid"
    t.check_constraint "original_quantity > 0", name: "inventory_batches_original_positive"
    t.check_constraint "quarantined_at IS NULL AND quarantined_by_id IS NULL AND quarantine_reason IS NULL OR quarantined_at IS NOT NULL AND quarantine_reason IS NOT NULL", name: "inventory_batches_quarantine_consistent"
    t.check_constraint "unit_cost_cents IS NULL OR unit_cost_cents >= 0", name: "inventory_batches_cost_nonnegative"
  end

  create_table "inventory_movements", force: :cascade do |t|
    t.bigint "actor_id"
    t.integer "batch_quantity_after"
    t.integer "batch_quantity_before"
    t.datetime "created_at", null: false
    t.string "idempotency_key"
    t.bigint "inventory_batch_id"
    t.jsonb "metadata", default: {}, null: false
    t.integer "movement_type", null: false
    t.bigint "product_id", null: false
    t.integer "quantity_after", null: false
    t.integer "quantity_before", null: false
    t.integer "quantity_delta", null: false
    t.text "reason", null: false
    t.bigint "reference_id"
    t.string "reference_type"
    t.index ["actor_id"], name: "index_inventory_movements_on_actor_id"
    t.index ["idempotency_key"], name: "index_inventory_movements_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["inventory_batch_id"], name: "index_inventory_movements_on_inventory_batch_id"
    t.index ["movement_type", "created_at"], name: "index_inventory_movements_reporting_type_time"
    t.index ["product_id", "created_at"], name: "index_inventory_movements_on_product_id_and_created_at"
    t.index ["product_id"], name: "index_inventory_movements_on_product_id"
    t.index ["reference_type", "reference_id"], name: "index_inventory_movements_on_reference"
    t.check_constraint "inventory_batch_id IS NULL AND batch_quantity_before IS NULL AND batch_quantity_after IS NULL OR inventory_batch_id IS NOT NULL AND batch_quantity_before >= 0 AND batch_quantity_after >= 0 AND batch_quantity_after = (batch_quantity_before + quantity_delta)", name: "inventory_movements_batch_quantities_valid"
    t.check_constraint "movement_type = ANY (ARRAY[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])", name: "inventory_movements_type_valid"
    t.check_constraint "quantity_before >= 0 AND quantity_after >= 0", name: "inventory_movements_quantities_nonnegative"
    t.check_constraint "quantity_delta <> 0", name: "inventory_movements_delta_nonzero"
  end

  create_table "inventory_reservation_allocations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "inventory_batch_id", null: false
    t.bigint "inventory_reservation_id", null: false
    t.integer "lock_version", default: 0, null: false
    t.integer "quantity", null: false
    t.datetime "updated_at", null: false
    t.index ["inventory_batch_id"], name: "index_inventory_reservation_allocations_on_inventory_batch_id"
    t.index ["inventory_reservation_id", "inventory_batch_id"], name: "index_reservation_allocations_unique_batch", unique: true
    t.index ["inventory_reservation_id"], name: "idx_on_inventory_reservation_id_f172ce2263"
    t.check_constraint "quantity > 0", name: "inventory_reservation_allocations_quantity_positive"
  end

  create_table "inventory_reservations", force: :cascade do |t|
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.bigint "order_id", null: false
    t.bigint "order_item_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", null: false
    t.datetime "released_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_inventory_reservations_on_order_id"
    t.index ["order_item_id", "status"], name: "index_inventory_reservations_unique_line_status", unique: true
    t.index ["product_id", "status"], name: "index_inventory_reservations_on_product_id_and_status"
    t.index ["product_id"], name: "index_inventory_reservations_on_product_id"
    t.index ["status", "product_id"], name: "index_inventory_reservations_reporting_status_product"
    t.check_constraint "quantity > 0", name: "inventory_reservations_quantity_positive"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2])", name: "inventory_reservations_status_valid"
  end

  create_table "job_heartbeats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.string "failure_class"
    t.string "job_name", null: false
    t.datetime "last_failed_at"
    t.datetime "last_started_at"
    t.datetime "last_succeeded_at"
    t.integer "processed_count"
    t.datetime "updated_at", null: false
    t.index ["job_name"], name: "index_job_heartbeats_on_job_name", unique: true
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "actor_id"
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.string "deduplication_key"
    t.string "kind", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "notifiable_id", null: false
    t.string "notifiable_type", null: false
    t.datetime "read_at"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["deduplication_key"], name: "index_notifications_on_deduplication_key", unique: true, where: "(deduplication_key IS NOT NULL)"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "order_addresses", force: :cascade do |t|
    t.string "apartment"
    t.string "building_number", null: false
    t.string "city", null: false
    t.datetime "created_at", null: false
    t.text "delivery_notes"
    t.string "district"
    t.string "floor"
    t.string "governorate", null: false
    t.string "label", null: false
    t.string "landmark"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.string "mobile_number", null: false
    t.bigint "order_id", null: false
    t.string "postal_code"
    t.string "recipient_name", null: false
    t.string "street", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_addresses_on_order_id", unique: true
  end

  create_table "order_events", force: :cascade do |t|
    t.bigint "actor_id"
    t.datetime "created_at", null: false
    t.boolean "customer_visible", default: false, null: false
    t.string "event_type", null: false
    t.string "from_status"
    t.jsonb "metadata", default: {}, null: false
    t.bigint "order_id", null: false
    t.string "to_status"
    t.index ["actor_id"], name: "index_order_events_on_actor_id"
    t.index ["event_type", "created_at"], name: "index_order_events_reporting_type_time"
    t.index ["event_type"], name: "index_order_events_on_event_type"
    t.index ["order_id", "created_at"], name: "index_order_events_on_order_id_and_created_at"
    t.index ["order_id"], name: "index_order_events_on_order_id"
    t.check_constraint "event_type::text = ANY (ARRAY['order_submitted'::character varying, 'prescription_review_started'::character varying, 'prescription_approved'::character varying, 'prescription_partially_approved'::character varying, 'prescription_rejected'::character varying, 'order_confirmed'::character varying, 'preparation_started'::character varying, 'order_ready'::character varying, 'out_for_delivery'::character varying, 'delivered'::character varying, 'cancelled'::character varying, 'rejected'::character varying, 'reservations_released'::character varying, 'reservations_consumed'::character varying, 'follow_up_opened'::character varying, 'customer_responded'::character varying, 'follow_up_resolved'::character varying, 'customer_cancelled'::character varying, 'staff_cancelled'::character varying, 'system_cancelled'::character varying, 'reservations_extended'::character varying, 'reservations_expired'::character varying, 'notification_sent'::character varying, 'fulfilment_assigned'::character varying, 'delivery_scheduled'::character varying, 'fulfilment_picking'::character varying, 'fulfilment_packed'::character varying, 'delivery_dispatched'::character varying, 'delivery_completed'::character varying, 'prescription_line_review_completed'::character varying]::text[])", name: "order_events_type_valid"
  end

  create_table "order_follow_up_messages", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.string "author_role", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.boolean "customer_visible", default: true, null: false
    t.bigint "order_follow_up_id", null: false
    t.index ["author_id"], name: "index_order_follow_up_messages_on_author_id"
    t.index ["order_follow_up_id"], name: "index_order_follow_up_messages_on_order_follow_up_id"
  end

  create_table "order_follow_ups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "customer_message", null: false
    t.datetime "due_at"
    t.text "internal_notes"
    t.integer "kind", null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "opened_by_id", null: false
    t.bigint "order_id", null: false
    t.bigint "prescription_id"
    t.datetime "resolved_at"
    t.bigint "resolved_by_id"
    t.datetime "responded_at"
    t.boolean "response_required", default: true, null: false
    t.integer "status", default: 1, null: false
    t.string "subject", null: false
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
    t.string "brand_name", null: false
    t.string "category_name", null: false
    t.integer "compare_at_price_cents"
    t.datetime "created_at", null: false
    t.integer "discount_cents", default: 0, null: false
    t.integer "final_unit_price_cents"
    t.integer "line_total_cents", null: false
    t.bigint "order_id", null: false
    t.integer "original_unit_price_cents"
    t.bigint "product_id"
    t.string "product_name", null: false
    t.string "product_slug", null: false
    t.integer "quantity", null: false
    t.boolean "requires_prescription", default: false, null: false
    t.integer "unit_price_cents", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_id", "order_id"], name: "index_order_items_reporting_product_order"
    t.index ["product_id"], name: "index_order_items_on_product_id"
    t.check_constraint "quantity > 0", name: "order_items_quantity_positive"
    t.check_constraint "unit_price_cents >= 0 AND discount_cents >= 0 AND line_total_cents >= 0", name: "order_items_money_nonnegative"
  end

  create_table "order_promotions", force: :cascade do |t|
    t.string "code"
    t.bigint "coupon_id"
    t.datetime "created_at", null: false
    t.integer "discount_cents", null: false
    t.string "discount_type", null: false
    t.integer "discount_value_snapshot", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "order_id", null: false
    t.bigint "promotion_id"
    t.string "promotion_name", null: false
    t.string "promotion_type", null: false
    t.datetime "updated_at", null: false
    t.index ["coupon_id"], name: "index_order_promotions_on_coupon_id"
    t.index ["order_id", "promotion_id"], name: "index_order_promotions_on_order_id_and_promotion_id", unique: true
    t.index ["order_id"], name: "index_order_promotions_on_order_id"
    t.index ["promotion_id"], name: "index_order_promotions_on_promotion_id"
  end

  create_table "orders", force: :cascade do |t|
    t.text "cancellation_reason"
    t.integer "cancellation_source"
    t.datetime "cancelled_at"
    t.bigint "cancelled_by_id"
    t.integer "cart_discount_cents", default: 0, null: false
    t.bigint "cart_id", null: false
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "currency", default: "EGP", null: false
    t.string "customer_email", null: false
    t.string "customer_first_name", null: false
    t.string "customer_last_name", null: false
    t.string "customer_mobile_number", null: false
    t.integer "delivery_discount_cents", default: 0, null: false
    t.integer "delivery_estimated_max_minutes"
    t.integer "delivery_estimated_min_minutes"
    t.integer "delivery_fee_cents", default: 0, null: false
    t.integer "delivery_method", null: false
    t.string "delivery_method_name"
    t.text "delivery_notes"
    t.bigint "delivery_slot_id"
    t.string "delivery_zone_code"
    t.bigint "delivery_zone_id"
    t.string "delivery_zone_name"
    t.integer "discount_cents", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.string "number", null: false
    t.integer "payment_method", null: false
    t.integer "payment_status", default: 0, null: false
    t.bigint "prescription_adjustment_cents", default: 0, null: false
    t.boolean "prescription_required", default: false, null: false
    t.string "pricing_calculation_version", default: "v1", null: false
    t.integer "product_discount_cents", default: 0, null: false
    t.datetime "scheduled_for"
    t.integer "status", null: false
    t.datetime "submitted_at", null: false
    t.integer "subtotal_cents", default: 0, null: false
    t.integer "total_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
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

  create_table "patient_allergies", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "active_ingredient_id", null: false
    t.datetime "created_at", null: false
    t.text "notes"
    t.bigint "patient_clinical_profile_id", null: false
    t.datetime "recorded_at", null: false
    t.bigint "recorded_by_id", null: false
    t.integer "severity", default: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["active_ingredient_id"], name: "index_patient_allergies_on_active_ingredient_id"
    t.index ["patient_clinical_profile_id", "active_ingredient_id"], name: "index_patient_allergies_unique_ingredient", unique: true
    t.index ["patient_clinical_profile_id"], name: "index_patient_allergies_on_profile"
    t.index ["recorded_by_id"], name: "index_patient_allergies_on_recorded_by_id"
    t.check_constraint "severity = ANY (ARRAY[0, 1, 2, 3])", name: "patient_allergies_severity_valid"
  end

  create_table "patient_clinical_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.integer "lactation_status", default: 0, null: false
    t.integer "lock_version", default: 0, null: false
    t.text "notes"
    t.integer "pregnancy_status", default: 0, null: false
    t.datetime "recorded_at", null: false
    t.bigint "recorded_by_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["recorded_by_id"], name: "index_patient_clinical_profiles_on_recorded_by_id"
    t.index ["user_id"], name: "index_patient_clinical_profiles_on_user_id", unique: true
    t.check_constraint "date_of_birth IS NULL OR date_of_birth > '1900-01-01'::date", name: "patient_clinical_profiles_dob_plausible"
    t.check_constraint "lactation_status = ANY (ARRAY[0, 1, 2])", name: "patient_clinical_profiles_lactation_valid"
    t.check_constraint "pregnancy_status = ANY (ARRAY[0, 1, 2])", name: "patient_clinical_profiles_pregnancy_valid"
  end

  create_table "pharmacy_settings", force: :cascade do |t|
    t.text "address_summary"
    t.datetime "created_at", null: false
    t.boolean "customer_registration_enabled", default: true, null: false
    t.string "default_currency", default: "EGP", null: false
    t.string "default_locale", default: "ar", null: false
    t.integer "default_low_stock_threshold", default: 5, null: false
    t.integer "default_maximum_order_quantity", default: 10, null: false
    t.integer "default_reservation_minutes", default: 30, null: false
    t.text "footer_text"
    t.boolean "guest_cart_enabled", default: true, null: false
    t.string "legal_name"
    t.integer "lock_version", default: 0, null: false
    t.text "maintenance_message"
    t.boolean "maintenance_mode", default: false, null: false
    t.integer "near_expiry_threshold_days", default: 90, null: false
    t.string "order_number_prefix", default: "PH", null: false
    t.integer "pending_prescription_reservation_hours", default: 24, null: false
    t.string "pharmacy_name", default: "صيدليتي", null: false
    t.boolean "prescription_review_enabled", default: true, null: false
    t.string "sender_email"
    t.string "sender_name"
    t.integer "singleton_key", default: 1, null: false
    t.string "support_email"
    t.string "support_hours"
    t.string "support_mobile"
    t.string "time_zone", default: "Africa/Cairo", null: false
    t.datetime "updated_at", null: false
    t.index ["singleton_key"], name: "index_pharmacy_settings_on_singleton_key", unique: true
    t.check_constraint "default_low_stock_threshold >= 0 AND default_maximum_order_quantity >= 1 AND default_maximum_order_quantity <= 100", name: "pharmacy_settings_product_defaults"
    t.check_constraint "default_reservation_minutes >= 5 AND default_reservation_minutes <= 1440 AND pending_prescription_reservation_hours >= 1 AND pending_prescription_reservation_hours <= 168", name: "pharmacy_settings_reservation_defaults"
    t.check_constraint "near_expiry_threshold_days >= 1 AND near_expiry_threshold_days <= 730", name: "pharmacy_settings_near_expiry_threshold_valid"
    t.check_constraint "singleton_key = 1", name: "pharmacy_settings_singleton"
  end

  create_table "pos_payments", force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.bigint "change_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "external_reference"
    t.integer "payment_method", null: false
    t.bigint "pos_sale_id", null: false
    t.bigint "tendered_cents"
    t.datetime "updated_at", null: false
    t.index ["pos_sale_id"], name: "index_pos_payments_on_pos_sale_id"
    t.check_constraint "amount_cents > 0", name: "pos_payments_amount_positive"
    t.check_constraint "payment_method = 0 AND tendered_cents >= amount_cents AND change_cents = (tendered_cents - amount_cents) OR payment_method = 1 AND tendered_cents IS NULL AND change_cents = 0", name: "pos_payments_tender_consistent"
    t.check_constraint "payment_method = ANY (ARRAY[0, 1])", name: "pos_payments_method_valid"
  end

  create_table "pos_sale_batch_allocations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "inventory_batch_id", null: false
    t.bigint "inventory_movement_id"
    t.bigint "pos_sale_item_id", null: false
    t.integer "quantity", null: false
    t.bigint "unit_cost_cents"
    t.datetime "updated_at", null: false
    t.index ["inventory_batch_id"], name: "index_pos_sale_batch_allocations_on_inventory_batch_id"
    t.index ["inventory_movement_id"], name: "index_pos_sale_batch_allocations_on_inventory_movement_id"
    t.index ["pos_sale_item_id", "inventory_batch_id"], name: "index_pos_allocations_unique_batch", unique: true
    t.index ["pos_sale_item_id"], name: "index_pos_sale_batch_allocations_on_pos_sale_item_id"
    t.check_constraint "quantity > 0", name: "pos_allocations_quantity_positive"
    t.check_constraint "unit_cost_cents IS NULL OR unit_cost_cents >= 0", name: "pos_allocations_cost_nonnegative"
  end

  create_table "pos_sale_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "discount_cents", default: 0, null: false
    t.bigint "line_total_cents", null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "original_unit_price_cents", null: false
    t.bigint "pos_sale_id", null: false
    t.text "prescription_approval_reason"
    t.datetime "prescription_approved_at"
    t.bigint "prescription_approved_by_id"
    t.string "product_barcode"
    t.bigint "product_id", null: false
    t.string "product_name", null: false
    t.string "product_sku"
    t.integer "quantity", null: false
    t.boolean "requires_prescription", default: false, null: false
    t.bigint "unit_price_cents", null: false
    t.datetime "updated_at", null: false
    t.index ["pos_sale_id", "product_id"], name: "index_pos_sale_items_on_pos_sale_id_and_product_id", unique: true
    t.index ["pos_sale_id"], name: "index_pos_sale_items_on_pos_sale_id"
    t.index ["prescription_approved_by_id"], name: "index_pos_sale_items_on_prescription_approved_by_id"
    t.index ["product_id"], name: "index_pos_sale_items_on_product_id"
    t.check_constraint "original_unit_price_cents >= 0 AND unit_price_cents >= 0 AND discount_cents >= 0 AND line_total_cents >= 0", name: "pos_sale_items_money_nonnegative"
    t.check_constraint "quantity > 0", name: "pos_sale_items_quantity_positive"
  end

  create_table "pos_sales", force: :cascade do |t|
    t.bigint "automatic_discount_cents", default: 0, null: false
    t.bigint "cashier_id", null: false
    t.bigint "cashier_session_id", null: false
    t.datetime "completed_at"
    t.string "completion_idempotency_key"
    t.datetime "created_at", null: false
    t.string "currency", default: "EGP", null: false
    t.datetime "discount_approved_at"
    t.bigint "discount_approved_by_id"
    t.integer "lock_version", default: 0, null: false
    t.bigint "manual_discount_cents", default: 0, null: false
    t.text "manual_discount_reason"
    t.string "number", null: false
    t.string "pricing_calculation_version"
    t.integer "status", default: 0, null: false
    t.bigint "subtotal_cents", default: 0, null: false
    t.bigint "tax_cents", default: 0, null: false
    t.bigint "total_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.text "void_reason"
    t.datetime "voided_at"
    t.bigint "voided_by_id"
    t.index ["cashier_id"], name: "index_pos_sales_on_cashier_id"
    t.index ["cashier_session_id"], name: "index_pos_sales_on_cashier_session_id"
    t.index ["completion_idempotency_key"], name: "index_pos_sales_on_completion_key", unique: true, where: "(completion_idempotency_key IS NOT NULL)"
    t.index ["discount_approved_by_id"], name: "index_pos_sales_on_discount_approved_by_id"
    t.index ["number"], name: "index_pos_sales_on_number", unique: true
    t.index ["status", "completed_at"], name: "index_pos_sales_on_status_and_completed_at"
    t.index ["voided_by_id"], name: "index_pos_sales_on_voided_by_id"
    t.check_constraint "currency::text = 'EGP'::text", name: "pos_sales_currency_valid"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2])", name: "pos_sales_status_valid"
    t.check_constraint "subtotal_cents >= 0 AND automatic_discount_cents >= 0 AND manual_discount_cents >= 0 AND tax_cents >= 0 AND total_cents >= 0", name: "pos_sales_money_nonnegative"
    t.check_constraint "total_cents = (subtotal_cents - automatic_discount_cents - manual_discount_cents + tax_cents)", name: "pos_sales_total_consistent"
  end

  create_table "prescription_decisions", force: :cascade do |t|
    t.bigint "actor_id", null: false
    t.datetime "created_at", null: false
    t.string "from_status", null: false
    t.jsonb "metadata", default: {}, null: false
    t.text "notes"
    t.bigint "prescription_review_item_id", null: false
    t.text "reason"
    t.string "to_status", null: false
    t.index ["actor_id"], name: "index_prescription_decisions_on_actor_id"
    t.index ["prescription_review_item_id", "created_at"], name: "index_prescription_decisions_timeline"
    t.index ["prescription_review_item_id"], name: "index_prescription_decisions_on_prescription_review_item_id"
    t.check_constraint "(from_status::text = ANY (ARRAY['pending'::character varying, 'under_review'::character varying, 'approved'::character varying, 'substituted'::character varying, 'rejected'::character varying]::text[])) AND (to_status::text = ANY (ARRAY['pending'::character varying, 'under_review'::character varying, 'approved'::character varying, 'substituted'::character varying, 'rejected'::character varying]::text[]))", name: "prescription_decisions_statuses_valid"
  end

  create_table "prescription_review_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "dispensed_product_id"
    t.bigint "dispensed_unit_price_cents"
    t.integer "lock_version", default: 0, null: false
    t.bigint "original_product_id", null: false
    t.text "pharmacist_notes"
    t.string "physician_instruction_reference"
    t.bigint "prescribed_unit_price_cents", null: false
    t.bigint "prescription_review_id", null: false
    t.integer "quantity", null: false
    t.text "reason"
    t.bigint "reviewable_item_id", null: false
    t.string "reviewable_item_type", null: false
    t.datetime "reviewed_at"
    t.bigint "reviewed_by_id"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["dispensed_product_id"], name: "index_prescription_review_items_on_dispensed_product_id"
    t.index ["original_product_id"], name: "index_prescription_review_items_on_original_product_id"
    t.index ["prescription_review_id", "reviewable_item_type", "reviewable_item_id"], name: "index_prescription_review_items_unique_source", unique: true
    t.index ["prescription_review_id"], name: "index_prescription_review_items_on_prescription_review_id"
    t.index ["reviewable_item_type", "reviewable_item_id"], name: "index_prescription_review_items_on_reviewable_item"
    t.index ["reviewed_by_id"], name: "index_prescription_review_items_on_reviewed_by_id"
    t.index ["status", "reviewed_at"], name: "index_prescription_review_items_on_status_and_reviewed_at"
    t.check_constraint "(status = ANY (ARRAY[0, 1])) AND reviewed_by_id IS NULL AND reviewed_at IS NULL AND dispensed_product_id IS NULL OR status = 2 AND reviewed_by_id IS NOT NULL AND reviewed_at IS NOT NULL AND dispensed_product_id = original_product_id OR status = 3 AND reviewed_by_id IS NOT NULL AND reviewed_at IS NOT NULL AND dispensed_product_id IS NOT NULL AND dispensed_product_id <> original_product_id OR status = 4 AND reviewed_by_id IS NOT NULL AND reviewed_at IS NOT NULL AND dispensed_product_id IS NULL", name: "prescription_review_items_decision_consistent"
    t.check_constraint "prescribed_unit_price_cents >= 0 AND (dispensed_unit_price_cents IS NULL OR dispensed_unit_price_cents >= 0)", name: "prescription_review_items_money_nonnegative"
    t.check_constraint "quantity > 0", name: "prescription_review_items_quantity_positive"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2, 3, 4])", name: "prescription_review_items_status_valid"
  end

  create_table "prescription_reviews", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "reviewable_id", null: false
    t.string "reviewable_type", null: false
    t.datetime "started_at"
    t.bigint "started_by_id"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["reviewable_type", "reviewable_id"], name: "index_prescription_reviews_on_reviewable"
    t.index ["reviewable_type", "reviewable_id"], name: "index_prescription_reviews_unique_reviewable", unique: true
    t.index ["started_by_id"], name: "index_prescription_reviews_on_started_by_id"
    t.index ["status", "created_at"], name: "index_prescription_reviews_on_status_and_created_at"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2])", name: "prescription_reviews_status_valid"
  end

  create_table "prescriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "customer_message"
    t.text "customer_notes"
    t.text "internal_notes"
    t.integer "lock_version", default: 0, null: false
    t.bigint "order_id", null: false
    t.text "rejection_reason"
    t.datetime "reviewed_at"
    t.bigint "reviewed_by_id"
    t.string "scan_failure_class"
    t.integer "scan_status", default: 1, null: false
    t.datetime "scanned_at"
    t.integer "status", default: 0, null: false
    t.datetime "submitted_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["order_id"], name: "index_prescriptions_on_order_id", unique: true
    t.index ["reviewed_by_id"], name: "index_prescriptions_on_reviewed_by_id"
    t.index ["scan_status", "created_at"], name: "index_prescriptions_on_scan_status_and_created_at"
    t.index ["status", "submitted_at"], name: "index_prescriptions_reporting_status_submitted"
    t.index ["user_id"], name: "index_prescriptions_on_user_id"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2, 3, 4])", name: "prescriptions_status_valid"
  end

  create_table "product_active_ingredients", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "active_ingredient_id", null: false
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.string "strength"
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["active_ingredient_id"], name: "index_product_active_ingredients_on_active_ingredient_id"
    t.index ["product_id", "active_ingredient_id"], name: "index_product_active_ingredients_unique", unique: true
    t.index ["product_id"], name: "index_product_active_ingredients_on_product_id"
  end

  create_table "product_images", force: :cascade do |t|
    t.string "alt_text", null: false
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.boolean "primary", default: false, null: false
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "position"], name: "index_product_images_on_product_id_and_position", unique: true
    t.index ["product_id"], name: "index_one_primary_image_per_product", unique: true, where: "(\"primary\" = true)"
    t.index ["product_id"], name: "index_product_images_on_product_id"
    t.check_constraint "\"position\" >= 0", name: "product_images_position_nonnegative"
  end

  create_table "product_price_changes", force: :cascade do |t|
    t.bigint "changed_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "effective_at", null: false
    t.integer "new_compare_at_price_cents"
    t.integer "new_cost_price_cents"
    t.integer "new_price_cents", null: false
    t.integer "old_compare_at_price_cents"
    t.integer "old_cost_price_cents"
    t.integer "old_price_cents", null: false
    t.bigint "product_id", null: false
    t.text "reason", null: false
    t.integer "source", default: 0, null: false
    t.index ["changed_by_id"], name: "index_product_price_changes_on_changed_by_id"
    t.index ["product_id", "effective_at"], name: "index_product_price_changes_on_product_id_and_effective_at"
    t.index ["product_id"], name: "index_product_price_changes_on_product_id"
    t.check_constraint "old_price_cents >= 0 AND new_price_cents >= 0", name: "price_changes_prices_nonnegative"
  end

  create_table "products", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "active_ingredient"
    t.string "barcode"
    t.bigint "brand_id", null: false
    t.bigint "category_id", null: false
    t.boolean "cold_chain_required", default: false, null: false
    t.decimal "compare_at_price", precision: 10, scale: 2
    t.decimal "cost_price", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "discontinued_at"
    t.string "dosage_form"
    t.boolean "featured", default: false, null: false
    t.integer "lock_version", default: 0, null: false
    t.integer "low_stock_threshold", default: 5, null: false
    t.string "manufacturer"
    t.integer "maximum_order_quantity", default: 10, null: false
    t.string "name", null: false
    t.boolean "pharmacist_review_required", default: false, null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.datetime "published_at"
    t.boolean "requires_prescription", default: false, null: false
    t.string "search_name"
    t.text "search_terms"
    t.string "short_description"
    t.string "sku"
    t.string "slug", null: false
    t.integer "stock_quantity", default: 0, null: false
    t.string "strength"
    t.datetime "updated_at", null: false
    t.index "upper((sku)::text)", name: "index_products_on_upper_sku", where: "(sku IS NOT NULL)"
    t.index ["active", "low_stock_threshold"], name: "index_products_on_active_and_low_stock_threshold"
    t.index ["active"], name: "index_products_on_active"
    t.index ["barcode"], name: "index_products_on_barcode", unique: true, where: "(barcode IS NOT NULL)"
    t.index ["brand_id"], name: "index_products_on_brand_id"
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["featured"], name: "index_products_on_featured"
    t.index ["search_name"], name: "index_products_on_search_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["search_terms"], name: "index_products_on_search_terms_trgm", opclass: :gin_trgm_ops, using: :gin
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
    t.string "action", null: false
    t.bigint "actor_id", null: false
    t.jsonb "changes", default: {}, null: false
    t.datetime "created_at", null: false
    t.bigint "promotion_id", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_promotion_audit_events_on_actor_id"
    t.index ["promotion_id"], name: "index_promotion_audit_events_on_promotion_id"
  end

  create_table "promotion_brands", force: :cascade do |t|
    t.bigint "brand_id", null: false
    t.datetime "created_at", null: false
    t.bigint "promotion_id", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id"], name: "index_promotion_brands_on_brand_id"
    t.index ["promotion_id", "brand_id"], name: "index_promotion_brands_unique", unique: true
    t.index ["promotion_id"], name: "index_promotion_brands_on_promotion_id"
  end

  create_table "promotion_categories", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.bigint "promotion_id", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_promotion_categories_on_category_id"
    t.index ["promotion_id", "category_id"], name: "index_promotion_categories_unique", unique: true
    t.index ["promotion_id"], name: "index_promotion_categories_on_promotion_id"
  end

  create_table "promotion_exclusions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.bigint "promotion_id", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_promotion_exclusions_on_product_id"
    t.index ["promotion_id", "product_id"], name: "index_promotion_exclusions_on_promotion_id_and_product_id", unique: true
    t.index ["promotion_id"], name: "index_promotion_exclusions_on_promotion_id"
  end

  create_table "promotion_products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.bigint "promotion_id", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_promotion_products_on_product_id"
    t.index ["promotion_id", "product_id"], name: "index_promotion_products_unique", unique: true
    t.index ["promotion_id"], name: "index_promotion_products_on_promotion_id"
  end

  create_table "promotion_redemptions", force: :cascade do |t|
    t.string "code_snapshot"
    t.bigint "coupon_id"
    t.datetime "created_at", null: false
    t.integer "discount_cents", null: false
    t.bigint "order_id", null: false
    t.bigint "promotion_id", null: false
    t.datetime "redeemed_at", null: false
    t.datetime "released_at"
    t.string "status", default: "redeemed", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
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
    t.boolean "active", default: false, null: false
    t.boolean "applies_to_prescription_products", default: false, null: false
    t.boolean "authenticated_only", default: false, null: false
    t.boolean "automatic", default: false, null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.string "delivery_method_code"
    t.bigint "delivery_zone_id"
    t.text "description"
    t.string "discount_type", null: false
    t.integer "discount_value", null: false
    t.datetime "ends_at", null: false
    t.boolean "first_order_only", default: false, null: false
    t.string "internal_name", null: false
    t.integer "lock_version", default: 0, null: false
    t.integer "maximum_discount_cents"
    t.jsonb "metadata", default: {}, null: false
    t.integer "minimum_subtotal_cents", default: 0, null: false
    t.string "name", null: false
    t.integer "per_customer_usage_limit"
    t.integer "priority", default: 0, null: false
    t.string "promotion_type", null: false
    t.boolean "stackable", default: false, null: false
    t.datetime "starts_at", null: false
    t.integer "total_usage_limit"
    t.datetime "updated_at", null: false
    t.bigint "updated_by_id", null: false
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

  create_table "purchase_order_events", force: :cascade do |t|
    t.bigint "actor_id"
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.string "from_status"
    t.jsonb "metadata", default: {}, null: false
    t.bigint "purchase_order_id", null: false
    t.string "to_status"
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_purchase_order_events_on_actor_id"
    t.index ["purchase_order_id", "created_at"], name: "idx_on_purchase_order_id_created_at_32548c016b"
    t.index ["purchase_order_id"], name: "index_purchase_order_events_on_purchase_order_id"
  end

  create_table "purchase_order_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "discount_cents", default: 0, null: false
    t.integer "line_total_cents", null: false
    t.integer "lock_version", default: 0, null: false
    t.text "notes"
    t.integer "ordered_quantity", null: false
    t.bigint "product_id", null: false
    t.string "product_name_snapshot", null: false
    t.bigint "purchase_order_id", null: false
    t.integer "received_quantity", default: 0, null: false
    t.string "sku_snapshot"
    t.integer "tax_cents", default: 0, null: false
    t.integer "unit_cost_cents", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_purchase_order_items_on_product_id"
    t.index ["purchase_order_id", "product_id"], name: "index_purchase_order_items_unique_product", unique: true
    t.index ["purchase_order_id"], name: "index_purchase_order_items_on_purchase_order_id"
    t.check_constraint "ordered_quantity > 0", name: "purchase_order_items_ordered_positive"
    t.check_constraint "received_quantity >= 0 AND received_quantity <= ordered_quantity", name: "purchase_order_items_received_valid"
    t.check_constraint "unit_cost_cents >= 0 AND discount_cents >= 0 AND tax_cents >= 0 AND line_total_cents >= 0", name: "purchase_order_items_money_nonnegative"
  end

  create_table "purchase_orders", force: :cascade do |t|
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.text "cancellation_reason"
    t.datetime "cancelled_at"
    t.bigint "cancelled_by_id"
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.string "currency", default: "EGP", null: false
    t.integer "discount_total_cents", default: 0, null: false
    t.date "expected_at"
    t.text "internal_notes"
    t.integer "lock_version", default: 0, null: false
    t.text "notes"
    t.string "number", null: false
    t.datetime "ordered_at"
    t.datetime "received_at"
    t.integer "status", default: 0, null: false
    t.datetime "submitted_at"
    t.integer "subtotal_cents", default: 0, null: false
    t.bigint "supplier_id", null: false
    t.integer "tax_total_cents", default: 0, null: false
    t.integer "total_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_purchase_orders_on_approved_by_id"
    t.index ["cancelled_by_id"], name: "index_purchase_orders_on_cancelled_by_id"
    t.index ["created_by_id"], name: "index_purchase_orders_on_created_by_id"
    t.index ["number"], name: "index_purchase_orders_on_number", unique: true
    t.index ["status", "expected_at"], name: "index_purchase_orders_on_status_and_expected_at"
    t.index ["supplier_id", "ordered_at"], name: "index_purchase_orders_on_supplier_id_and_ordered_at"
    t.index ["supplier_id"], name: "index_purchase_orders_on_supplier_id"
    t.check_constraint "currency::text = 'EGP'::text", name: "purchase_orders_currency_valid"
    t.check_constraint "status >= 0 AND status <= 6", name: "purchase_orders_status_valid"
    t.check_constraint "subtotal_cents >= 0 AND discount_total_cents >= 0 AND tax_total_cents >= 0 AND total_cents >= 0", name: "purchase_orders_money_nonnegative"
  end

  create_table "purchase_receipt_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "inventory_movement_id"
    t.bigint "purchase_order_item_id", null: false
    t.bigint "purchase_receipt_id", null: false
    t.integer "quantity", null: false
    t.integer "unit_cost_cents", null: false
    t.datetime "updated_at", null: false
    t.index ["inventory_movement_id"], name: "index_purchase_receipt_items_on_inventory_movement_id"
    t.index ["purchase_order_item_id"], name: "index_purchase_receipt_items_on_purchase_order_item_id"
    t.index ["purchase_receipt_id", "purchase_order_item_id"], name: "index_purchase_receipt_items_unique_line", unique: true
    t.index ["purchase_receipt_id"], name: "index_purchase_receipt_items_on_purchase_receipt_id"
    t.check_constraint "quantity > 0", name: "purchase_receipt_items_quantity_positive"
    t.check_constraint "unit_cost_cents >= 0", name: "purchase_receipt_items_cost_nonnegative"
  end

  create_table "purchase_receipts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "idempotency_key", null: false
    t.text "notes"
    t.bigint "purchase_order_id", null: false
    t.datetime "received_at", null: false
    t.bigint "received_by_id", null: false
    t.string "reference", null: false
    t.string "supplier_document_number"
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_purchase_receipts_on_idempotency_key", unique: true
    t.index ["purchase_order_id"], name: "index_purchase_receipts_on_purchase_order_id"
    t.index ["received_by_id"], name: "index_purchase_receipts_on_received_by_id"
    t.index ["reference"], name: "index_purchase_receipts_on_reference", unique: true
  end

  create_table "report_export_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "filters", default: {}, null: false
    t.string "format", default: "csv", null: false
    t.datetime "range_end", null: false
    t.datetime "range_start", null: false
    t.string "report_type", null: false
    t.integer "row_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "created_at"], name: "index_report_export_events_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_report_export_events_on_user_id"
    t.check_constraint "format::text = 'csv'::text", name: "report_export_events_format_valid"
    t.check_constraint "range_end > range_start AND row_count >= 0", name: "report_export_events_range_rows_valid"
    t.check_constraint "report_type::text = ANY (ARRAY['sales'::character varying, 'orders'::character varying, 'products'::character varying, 'inventory'::character varying, 'promotions'::character varying, 'customers'::character varying, 'prescriptions'::character varying, 'fulfilments'::character varying, 'purchasing'::character varying, 'batches'::character varying, 'pos'::character varying, 'drug_safety'::character varying, 'search'::character varying]::text[])", name: "report_export_events_type_valid"
  end

  create_table "report_exports", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "deduplication_key", null: false
    t.string "error_class"
    t.datetime "expires_at"
    t.datetime "failed_at"
    t.jsonb "filters", default: {}, null: false
    t.string "report_type", null: false
    t.datetime "requested_at", null: false
    t.integer "row_count"
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["deduplication_key"], name: "index_report_exports_on_deduplication_key"
    t.index ["status", "expires_at"], name: "index_report_exports_on_status_and_expires_at"
    t.index ["user_id", "status", "created_at"], name: "index_report_exports_on_user_id_and_status_and_created_at"
    t.index ["user_id"], name: "index_report_exports_on_user_id"
  end

  create_table "search_events", force: :cascade do |t|
    t.string "context", null: false
    t.datetime "created_at", null: false
    t.string "normalized_query"
    t.string "query_fingerprint", null: false
    t.integer "result_count", default: 0, null: false
    t.bigint "selected_product_id"
    t.integer "token_count", default: 0, null: false
    t.boolean "zero_result", default: false, null: false
    t.index ["context", "created_at"], name: "index_search_events_on_context_and_created_at"
    t.index ["query_fingerprint", "created_at"], name: "index_search_events_on_fingerprint_and_created_at"
    t.index ["selected_product_id"], name: "index_search_events_on_selected_product_id"
    t.index ["zero_result", "created_at"], name: "index_search_events_on_zero_result_and_created_at"
    t.check_constraint "char_length(normalized_query::text) <= 120", name: "search_events_query_bounded"
    t.check_constraint "context::text = ANY (ARRAY['storefront'::character varying, 'pos'::character varying, 'substitution'::character varying, 'staff'::character varying, 'suggestion'::character varying]::text[])", name: "search_events_context_valid"
    t.check_constraint "result_count >= 0 AND token_count >= 0", name: "search_events_counts_nonnegative"
    t.check_constraint "zero_result = (result_count = 0)", name: "search_events_zero_result_consistent"
  end

  create_table "search_synonyms", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "expansion", null: false
    t.string "normalized_expansion", null: false
    t.string "normalized_term", null: false
    t.text "notes"
    t.string "term", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "normalized_term"], name: "index_search_synonyms_lookup"
    t.index ["normalized_term", "normalized_expansion"], name: "index_search_synonyms_unique_pair", unique: true
    t.check_constraint "char_length(normalized_expansion::text) >= 2 AND char_length(normalized_expansion::text) <= 60", name: "search_synonyms_expansion_length"
    t.check_constraint "char_length(normalized_term::text) >= 2 AND char_length(normalized_term::text) <= 60", name: "search_synonyms_term_length"
    t.check_constraint "normalized_term::text <> normalized_expansion::text", name: "search_synonyms_pair_differs"
  end

  create_table "security_events", force: :cascade do |t|
    t.bigint "actor_id"
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.string "ip_digest"
    t.jsonb "metadata", default: {}, null: false
    t.string "user_agent_summary", limit: 200
    t.bigint "user_id"
    t.index ["actor_id"], name: "index_security_events_on_actor_id"
    t.index ["event_type", "created_at"], name: "index_security_events_on_event_type_and_created_at"
    t.index ["user_id"], name: "index_security_events_on_user_id"
  end

  create_table "settings_audit_events", force: :cascade do |t|
    t.string "action", default: "updated", null: false
    t.bigint "actor_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "new_values", default: {}, null: false
    t.jsonb "old_values", default: {}, null: false
    t.text "reason"
    t.index ["actor_id"], name: "index_settings_audit_events_on_actor_id"
    t.index ["created_at"], name: "index_settings_audit_events_on_created_at"
  end

  create_table "suppliers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "address"
    t.string "code", null: false
    t.string "contact_person"
    t.datetime "created_at", null: false
    t.string "email"
    t.integer "lead_time_days"
    t.string "legal_name"
    t.integer "lock_version", default: 0, null: false
    t.string "name", null: false
    t.text "notes"
    t.string "payment_terms"
    t.string "phone"
    t.string "tax_identifier"
    t.datetime "updated_at", null: false
    t.index "lower((code)::text)", name: "index_suppliers_on_lower_code", unique: true
    t.index ["active"], name: "index_suppliers_on_active"
    t.check_constraint "lead_time_days IS NULL OR lead_time_days >= 0", name: "suppliers_lead_time_nonnegative"
  end

  create_table "therapeutic_substitutions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "original_product_id", null: false
    t.bigint "pharmacist_id", null: false
    t.string "physician_instruction_reference"
    t.bigint "prescription_review_item_id", null: false
    t.text "reason", null: false
    t.bigint "substitute_product_id", null: false
    t.datetime "substituted_at", null: false
    t.datetime "updated_at", null: false
    t.index ["original_product_id"], name: "index_therapeutic_substitutions_on_original_product_id"
    t.index ["pharmacist_id"], name: "index_therapeutic_substitutions_on_pharmacist_id"
    t.index ["prescription_review_item_id"], name: "index_therapeutic_substitutions_on_prescription_review_item_id"
    t.index ["prescription_review_item_id"], name: "index_therapeutic_substitutions_unique_item", unique: true
    t.index ["substitute_product_id"], name: "index_therapeutic_substitutions_on_substitute_product_id"
    t.check_constraint "original_product_id <> substitute_product_id", name: "therapeutic_substitutions_products_differ"
  end

  create_table "transactional_email_deliveries", force: :cascade do |t|
    t.string "action", null: false
    t.integer "attempts_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "deduplication_key", null: false
    t.datetime "delivered_at"
    t.datetime "failed_at"
    t.string "last_error_class"
    t.string "mailer", null: false
    t.bigint "notification_id"
    t.datetime "queued_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["deduplication_key"], name: "index_transactional_email_deliveries_on_deduplication_key", unique: true
    t.index ["notification_id"], name: "index_transactional_email_deliveries_on_notification_id"
    t.index ["status", "updated_at"], name: "index_transactional_email_deliveries_on_status_and_updated_at"
    t.index ["user_id"], name: "index_transactional_email_deliveries_on_user_id"
  end

  create_table "user_audit_events", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "actor_id"
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.jsonb "new_values", default: {}, null: false
    t.jsonb "old_values", default: {}, null: false
    t.text "reason"
    t.bigint "user_id", null: false
    t.index ["actor_id"], name: "index_user_audit_events_on_actor_id"
    t.index ["user_id", "created_at"], name: "index_user_audit_events_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_user_audit_events_on_user_id"
    t.check_constraint "action::text = ANY (ARRAY['invited'::character varying, 'invitation_resent'::character varying, 'invitation_revoked'::character varying, 'invitation_accepted'::character varying, 'activated'::character varying, 'deactivated'::character varying, 'role_changed'::character varying, 'profile_updated_by_admin'::character varying, 'account_unlocked'::character varying, 'password_reset_requested_by_admin'::character varying, 'bootstrap_admin'::character varying]::text[])", name: "user_audit_events_action_valid"
  end

  create_table "user_invitations", force: :cascade do |t|
    t.datetime "accepted_at"
    t.integer "attempts_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "invited_by_id", null: false
    t.datetime "revoked_at"
    t.datetime "sent_at", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["expires_at"], name: "index_user_invitations_on_expires_at"
    t.index ["invited_by_id"], name: "index_user_invitations_on_invited_by_id"
    t.index ["token_digest"], name: "index_user_invitations_on_token_digest", unique: true
    t.index ["user_id"], name: "index_user_invitations_on_user_id"
    t.check_constraint "attempts_count >= 0", name: "user_invitations_attempts_nonnegative"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.bigint "last_otp_timestep"
    t.datetime "last_sign_in_at"
    t.datetime "locked_at"
    t.string "mobile_number", null: false
    t.datetime "otp_enabled_at"
    t.text "otp_secret"
    t.jsonb "recovery_code_digests", default: [], null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.integer "session_version", default: 0, null: false
    t.integer "sign_in_count", default: 0, null: false
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["last_sign_in_at"], name: "index_users_on_last_sign_in_at"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role", "active"], name: "index_users_on_role_and_active"
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
    t.check_constraint "role = ANY (ARRAY[0, 1, 2, 3, 4])", name: "users_role_valid"
  end

  create_table "wishlist_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
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
  add_foreign_key "cashier_sessions", "users"
  add_foreign_key "coupons", "promotions"
  add_foreign_key "delivery_methods", "delivery_zones"
  add_foreign_key "delivery_slots", "delivery_zones"
  add_foreign_key "delivery_zone_districts", "delivery_zones"
  add_foreign_key "drug_safety_acknowledgements", "drug_safety_findings"
  add_foreign_key "drug_safety_acknowledgements", "users", column: "pharmacist_id"
  add_foreign_key "drug_safety_evaluations", "prescription_reviews"
  add_foreign_key "drug_safety_evaluations", "users", column: "actor_id"
  add_foreign_key "drug_safety_findings", "drug_safety_evaluations"
  add_foreign_key "drug_safety_findings", "drug_safety_findings", column: "carried_from_id"
  add_foreign_key "drug_safety_findings", "drug_safety_rules"
  add_foreign_key "drug_safety_findings", "prescription_review_items"
  add_foreign_key "drug_safety_findings", "prescription_review_items", column: "related_review_item_id"
  add_foreign_key "drug_safety_findings", "users", column: "resolved_by_id"
  add_foreign_key "drug_safety_rule_conditions", "active_ingredients"
  add_foreign_key "drug_safety_rule_conditions", "drug_safety_rules"
  add_foreign_key "drug_safety_rules", "users", column: "created_by_id"
  add_foreign_key "fulfilments", "delivery_slots"
  add_foreign_key "fulfilments", "delivery_zones"
  add_foreign_key "fulfilments", "orders"
  add_foreign_key "fulfilments", "users", column: "assigned_by_id"
  add_foreign_key "fulfilments", "users", column: "assigned_to_id"
  add_foreign_key "inventory_batch_events", "inventory_batches"
  add_foreign_key "inventory_batch_events", "users", column: "actor_id"
  add_foreign_key "inventory_batches", "products"
  add_foreign_key "inventory_batches", "purchase_receipt_items"
  add_foreign_key "inventory_batches", "purchase_receipts"
  add_foreign_key "inventory_batches", "suppliers"
  add_foreign_key "inventory_batches", "users", column: "quarantined_by_id"
  add_foreign_key "inventory_movements", "inventory_batches"
  add_foreign_key "inventory_movements", "products"
  add_foreign_key "inventory_movements", "users", column: "actor_id"
  add_foreign_key "inventory_reservation_allocations", "inventory_batches"
  add_foreign_key "inventory_reservation_allocations", "inventory_reservations"
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
  add_foreign_key "patient_allergies", "active_ingredients"
  add_foreign_key "patient_allergies", "patient_clinical_profiles"
  add_foreign_key "patient_allergies", "users", column: "recorded_by_id"
  add_foreign_key "patient_clinical_profiles", "users"
  add_foreign_key "patient_clinical_profiles", "users", column: "recorded_by_id"
  add_foreign_key "pos_payments", "pos_sales"
  add_foreign_key "pos_sale_batch_allocations", "inventory_batches"
  add_foreign_key "pos_sale_batch_allocations", "inventory_movements"
  add_foreign_key "pos_sale_batch_allocations", "pos_sale_items"
  add_foreign_key "pos_sale_items", "pos_sales"
  add_foreign_key "pos_sale_items", "products"
  add_foreign_key "pos_sale_items", "users", column: "prescription_approved_by_id"
  add_foreign_key "pos_sales", "cashier_sessions"
  add_foreign_key "pos_sales", "users", column: "cashier_id"
  add_foreign_key "pos_sales", "users", column: "discount_approved_by_id"
  add_foreign_key "pos_sales", "users", column: "voided_by_id"
  add_foreign_key "prescription_decisions", "prescription_review_items"
  add_foreign_key "prescription_decisions", "users", column: "actor_id"
  add_foreign_key "prescription_review_items", "prescription_reviews"
  add_foreign_key "prescription_review_items", "products", column: "dispensed_product_id"
  add_foreign_key "prescription_review_items", "products", column: "original_product_id"
  add_foreign_key "prescription_review_items", "users", column: "reviewed_by_id"
  add_foreign_key "prescription_reviews", "users", column: "started_by_id"
  add_foreign_key "prescriptions", "orders", on_delete: :cascade
  add_foreign_key "prescriptions", "users"
  add_foreign_key "prescriptions", "users", column: "reviewed_by_id"
  add_foreign_key "product_active_ingredients", "active_ingredients"
  add_foreign_key "product_active_ingredients", "products"
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
  add_foreign_key "purchase_order_events", "purchase_orders"
  add_foreign_key "purchase_order_events", "users", column: "actor_id"
  add_foreign_key "purchase_order_items", "products"
  add_foreign_key "purchase_order_items", "purchase_orders"
  add_foreign_key "purchase_orders", "suppliers"
  add_foreign_key "purchase_orders", "users", column: "approved_by_id"
  add_foreign_key "purchase_orders", "users", column: "cancelled_by_id"
  add_foreign_key "purchase_orders", "users", column: "created_by_id"
  add_foreign_key "purchase_receipt_items", "inventory_movements"
  add_foreign_key "purchase_receipt_items", "purchase_order_items"
  add_foreign_key "purchase_receipt_items", "purchase_receipts"
  add_foreign_key "purchase_receipts", "purchase_orders"
  add_foreign_key "purchase_receipts", "users", column: "received_by_id"
  add_foreign_key "report_export_events", "users"
  add_foreign_key "report_exports", "users"
  add_foreign_key "search_events", "products", column: "selected_product_id"
  add_foreign_key "security_events", "users"
  add_foreign_key "security_events", "users", column: "actor_id"
  add_foreign_key "settings_audit_events", "users", column: "actor_id"
  add_foreign_key "therapeutic_substitutions", "prescription_review_items"
  add_foreign_key "therapeutic_substitutions", "products", column: "original_product_id"
  add_foreign_key "therapeutic_substitutions", "products", column: "substitute_product_id"
  add_foreign_key "therapeutic_substitutions", "users", column: "pharmacist_id"
  add_foreign_key "transactional_email_deliveries", "notifications"
  add_foreign_key "transactional_email_deliveries", "users"
  add_foreign_key "user_audit_events", "users"
  add_foreign_key "user_audit_events", "users", column: "actor_id"
  add_foreign_key "user_invitations", "users"
  add_foreign_key "user_invitations", "users", column: "invited_by_id"
  add_foreign_key "wishlist_items", "products", on_delete: :cascade
  add_foreign_key "wishlist_items", "users", on_delete: :cascade
end
