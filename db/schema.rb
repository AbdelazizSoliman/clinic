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

ActiveRecord::Schema[7.2].define(version: 2026_07_16_010003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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
    t.index ["guest_token"], name: "index_carts_on_guest_token", unique: true, where: "(guest_token IS NOT NULL)"
    t.index ["user_id"], name: "index_carts_on_user_id"
    t.index ["user_id"], name: "index_one_active_cart_per_user", unique: true, where: "((status = 0) AND (user_id IS NOT NULL))"
    t.check_constraint "(user_id IS NOT NULL) <> (guest_token IS NOT NULL)", name: "carts_exactly_one_owner"
    t.check_constraint "status = ANY (ARRAY[0, 1, 2])", name: "carts_status_valid"
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

  add_foreign_key "cart_items", "carts", on_delete: :cascade
  add_foreign_key "cart_items", "products"
  add_foreign_key "carts", "users"
  add_foreign_key "products", "brands"
  add_foreign_key "products", "categories"
end
