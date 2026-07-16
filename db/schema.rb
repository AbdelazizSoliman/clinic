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

ActiveRecord::Schema[7.2].define(version: 2026_07_16_030003) do
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

  create_table "brands", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["name"], name: "index_categories_on_name", unique: true
    t.index ["slug"], name: "index_categories_on_slug", unique: true
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
    t.check_constraint "quantity > 0", name: "inventory_reservations_quantity_positive"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2])", name: "inventory_reservations_status_valid"
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
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_id"], name: "index_order_items_on_product_id"
    t.check_constraint "quantity > 0", name: "order_items_quantity_positive"
    t.check_constraint "unit_price_cents >= 0 AND discount_cents >= 0 AND line_total_cents >= 0", name: "order_items_money_nonnegative"
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
    t.index ["cart_id"], name: "index_orders_on_cart_id", unique: true
    t.index ["number"], name: "index_orders_on_number", unique: true
    t.index ["user_id", "submitted_at"], name: "index_orders_on_user_id_and_submitted_at"
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
    t.index ["order_id"], name: "index_prescriptions_on_order_id", unique: true
    t.index ["reviewed_by_id"], name: "index_prescriptions_on_reviewed_by_id"
    t.index ["user_id"], name: "index_prescriptions_on_user_id"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2, 3, 4])", name: "prescriptions_status_valid"
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
    t.index ["active"], name: "index_products_on_active"
    t.index ["brand_id"], name: "index_products_on_brand_id"
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["featured"], name: "index_products_on_featured"
    t.index ["slug"], name: "index_products_on_slug", unique: true
    t.check_constraint "compare_at_price IS NULL OR compare_at_price >= 0::numeric", name: "products_compare_at_price_non_negative"
    t.check_constraint "price >= 0::numeric", name: "products_price_non_negative"
    t.check_constraint "stock_quantity >= 0", name: "products_stock_nonnegative"
    t.check_constraint "stock_quantity >= 0", name: "products_stock_quantity_non_negative"
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
    t.check_constraint "role = ANY (ARRAY[0, 1])", name: "users_role_valid"
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
  add_foreign_key "cart_items", "carts", on_delete: :cascade
  add_foreign_key "cart_items", "products"
  add_foreign_key "carts", "users"
  add_foreign_key "inventory_reservations", "order_items", on_delete: :cascade
  add_foreign_key "inventory_reservations", "orders", on_delete: :cascade
  add_foreign_key "inventory_reservations", "products"
  add_foreign_key "order_addresses", "orders", on_delete: :cascade
  add_foreign_key "order_items", "orders", on_delete: :cascade
  add_foreign_key "order_items", "products", on_delete: :nullify
  add_foreign_key "orders", "carts"
  add_foreign_key "orders", "users"
  add_foreign_key "prescriptions", "orders", on_delete: :cascade
  add_foreign_key "prescriptions", "users"
  add_foreign_key "prescriptions", "users", column: "reviewed_by_id"
  add_foreign_key "products", "brands"
  add_foreign_key "products", "categories"
  add_foreign_key "wishlist_items", "products", on_delete: :cascade
  add_foreign_key "wishlist_items", "users", on_delete: :cascade
end
