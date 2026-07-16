class AddPromotionsAndCommercialPricing < ActiveRecord::Migration[7.2]
  def change
    create_table :promotions do |t|
      t.string :name, null: false
      t.string :internal_name, null: false
      t.text :description
      t.string :promotion_type, null: false
      t.string :discount_type, null: false
      t.integer :discount_value, null: false
      t.integer :maximum_discount_cents
      t.integer :minimum_subtotal_cents, null: false, default: 0
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.boolean :active, null: false, default: false
      t.integer :priority, null: false, default: 0
      t.boolean :stackable, null: false, default: false
      t.boolean :automatic, null: false, default: false
      t.boolean :first_order_only, null: false, default: false
      t.boolean :authenticated_only, null: false, default: false
      t.boolean :applies_to_prescription_products, null: false, default: false
      t.integer :total_usage_limit
      t.integer :per_customer_usage_limit
      t.references :delivery_zone, foreign_key: true
      t.string :delivery_method_code
      t.jsonb :metadata, null: false, default: {}
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :updated_by, null: false, foreign_key: { to_table: :users }
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_check_constraint :promotions, "promotion_type IN ('product','category','brand','cart','delivery')", name: "promotions_type_valid"
    add_check_constraint :promotions, "discount_type IN ('percentage','fixed_amount','fixed_price','free_delivery')", name: "promotions_discount_type_valid"
    add_check_constraint :promotions, "discount_value >= 0 AND minimum_subtotal_cents >= 0 AND priority >= 0", name: "promotions_values_nonnegative"
    add_check_constraint :promotions, "ends_at > starts_at", name: "promotions_time_range_valid"
    add_check_constraint :promotions, "total_usage_limit IS NULL OR total_usage_limit > 0", name: "promotions_total_limit_positive"
    add_check_constraint :promotions, "per_customer_usage_limit IS NULL OR per_customer_usage_limit > 0", name: "promotions_customer_limit_positive"
    add_index :promotions, %i[active starts_at ends_at]

    create_table :coupons do |t|
      t.references :promotion, null: false, foreign_key: true
      t.string :code, null: false
      t.string :normalized_code, null: false
      t.boolean :active, null: false, default: true
      t.datetime :starts_at
      t.datetime :ends_at
      t.integer :total_usage_limit
      t.integer :per_customer_usage_limit
      t.integer :minimum_subtotal_cents
      t.integer :maximum_discount_cents
      t.boolean :first_order_only
      t.boolean :authenticated_only
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :coupons, "lower(normalized_code)", unique: true, name: "index_coupons_on_lower_normalized_code"
    add_check_constraint :coupons, "total_usage_limit IS NULL OR total_usage_limit > 0", name: "coupons_total_limit_positive"
    add_check_constraint :coupons, "per_customer_usage_limit IS NULL OR per_customer_usage_limit > 0", name: "coupons_customer_limit_positive"

    %i[products categories brands].each do |target|
      create_table "promotion_#{target}" do |t|
        t.references :promotion, null: false, foreign_key: true
        t.references target.to_s.singularize, null: false, foreign_key: true
        t.timestamps
      end
      add_index "promotion_#{target}", [ :promotion_id, "#{target.to_s.singularize}_id" ], unique: true,
        name: "index_promotion_#{target}_unique"
    end
    create_table :promotion_exclusions do |t|
      t.references :promotion, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.timestamps
    end
    add_index :promotion_exclusions, %i[promotion_id product_id], unique: true

    add_reference :carts, :applied_coupon, foreign_key: { to_table: :coupons }
    add_column :carts, :applied_coupon_code_snapshot, :string
    add_column :carts, :lock_version, :integer, null: false, default: 0 unless column_exists?(:carts, :lock_version)

    add_column :orders, :product_discount_cents, :integer, null: false, default: 0
    add_column :orders, :cart_discount_cents, :integer, null: false, default: 0
    add_column :orders, :delivery_discount_cents, :integer, null: false, default: 0
    add_column :orders, :pricing_calculation_version, :string, null: false, default: "v1"
    add_column :order_items, :original_unit_price_cents, :integer
    add_column :order_items, :final_unit_price_cents, :integer

    create_table :order_promotions do |t|
      t.references :order, null: false, foreign_key: true
      t.references :promotion, foreign_key: true
      t.references :coupon, foreign_key: true
      t.string :promotion_name, null: false
      t.string :code
      t.string :promotion_type, null: false
      t.string :discount_type, null: false
      t.integer :discount_value_snapshot, null: false
      t.integer :discount_cents, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :order_promotions, %i[order_id promotion_id], unique: true

    create_table :promotion_redemptions do |t|
      t.references :promotion, null: false, foreign_key: true
      t.references :coupon, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true
      t.string :code_snapshot
      t.integer :discount_cents, null: false
      t.string :status, null: false, default: "redeemed"
      t.datetime :redeemed_at, null: false
      t.datetime :released_at
      t.timestamps
    end
    add_index :promotion_redemptions, %i[promotion_id order_id], unique: true
    add_index :promotion_redemptions, :order_id, unique: true, where: "coupon_id IS NOT NULL", name: "index_one_coupon_redemption_per_order"
    add_check_constraint :promotion_redemptions, "status IN ('redeemed','released')", name: "promotion_redemptions_status_valid"
    add_check_constraint :promotion_redemptions, "discount_cents >= 0", name: "promotion_redemptions_discount_nonnegative"

    create_table :promotion_audit_events do |t|
      t.references :promotion, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.jsonb :changes, null: false, default: {}
      t.timestamps
    end
  end
end
