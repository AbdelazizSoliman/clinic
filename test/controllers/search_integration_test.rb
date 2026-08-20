require "test_helper"

class SearchIntegrationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @pharmacist = users(:pharmacist)
    @customer = users(:customer)
    @category = categories(:medicines)
    @brand = brands(:eva)
    @ingredient = ActiveIngredient.create!(code: "ALFA", name: "ألفازين")
    @rx = rx_product("دواء تجريبي للبحث", ingredients: [ @ingredient ])
    @inactive = rx_product("دواء موقوف للبحث", active: false)
  end

  # ---------- storefront ----------

  test "storefront search finds an alternate arabic spelling and keeps filter state in the URL" do
    product = Product.create!(name: "شراب إبراهيم للأطفال", slug: "ibrahim-syrup", price: 30, stock_quantity: 5,
      category: @category, brand: @brand)
    get products_path(q: "شراب ابراهيم")
    assert_response :success
    assert_match product.name, response.body

    get products_path(q: "شراب", category: @category.slug, sort: "name")
    assert_response :success
    assert_select "input[name='q'][value='شراب']"
  end

  test "a zero-result storefront search renders safe guidance rather than an error" do
    get products_path(q: "منتج غير موجود اطلاقا")
    assert_response :success
    assert_match "لا توجد نتائج", response.body
    assert_match "تصفّح الأقسام", response.body
  end

  test "customers never see inactive products through search" do
    get products_path(q: "للبحث")
    assert_response :success
    assert_match @rx.name, response.body
    assert_no_match "موقوف للبحث", response.body
  end

  test "search text is escaped rather than rendered as markup" do
    get products_path(q: "<script>alert(1)</script>")
    assert_response :success
    assert_no_match "<script>alert(1)</script>", response.body
    assert_match "&lt;script&gt;", response.body
  end

  # ---------- suggestions ----------

  test "suggestions are public, bounded and context aware" do
    get search_suggestions_path(q: "دواء")
    assert_response :success
    assert_no_match @inactive.name, response.body
    assert_select "li[role='option']", minimum: 1

    get search_suggestions_path(q: "د")
    assert_response :success
    assert_select "li[role='option']", 0
  end

  test "an oversized suggestion query is bounded and safe" do
    get search_suggestions_path(q: "ا" * 5_000)
    assert_response :success
  end

  # ---------- pos ----------

  test "pos search requires pos authorization" do
    get pos_products_path(q: "دواء")
    assert_redirected_to new_user_session_path

    sign_in @customer
    get pos_products_path(q: "دواء")
    assert_response :not_found
  end

  test "pos exact barcode returns the product first and flags the exact match" do
    sign_in @pharmacist
    get pos_products_path(q: @rx.barcode)
    assert_response :success
    assert_match "مطابقة دقيقة", response.body
    assert_match @rx.name, response.body
  end

  test "pos reports a missing identifier clearly" do
    sign_in @pharmacist
    get pos_products_path(q: "9999999999999")
    assert_response :success
    assert_match "لا يوجد منتج مطابق", response.body
  end

  # ---------- substitution ----------

  test "substitution candidate search is pharmacist only" do
    %i[customer order_manager inventory_manager admin].each do |role|
      sign_in users(role)
      get staff_substitution_candidates_path(q: "دواء")
      assert_response :not_found, "#{role} must not use the clinical substitution lookup"
      sign_out users(role)
    end

    sign_in @pharmacist
    get staff_substitution_candidates_path(q: "دواء")
    assert_response :success
  end

  test "substitution results state plainly that search implies no clinical equivalence" do
    sign_in @pharmacist
    get staff_substitution_candidates_path(q: "دواء")
    assert_response :success
    assert_match "لا يرتب البدائل سريريًا", response.body
    assert_select "input[type='radio'][name='substitute_product_id']", minimum: 1
  end

  test "substitution search finds a product by its structured active ingredient" do
    sign_in @pharmacist
    get staff_substitution_candidates_path(q: @ingredient.name)
    assert_response :success
    assert_match @rx.name, response.body
  end

  test "substitution search excludes the original product and unavailable candidates" do
    sign_in @pharmacist
    get staff_substitution_candidates_path(q: "دواء", exclude_id: @rx.id)
    assert_response :success
    assert_no_match @rx.name, response.body
    assert_no_match @inactive.name, response.body
  end

  # ---------- analytics and reporting ----------

  test "storefront searches are recorded without any searcher identity" do
    assert_difference "SearchEvent.count", 1 do
      get products_path(q: "دواء تجريبي")
    end
    event = SearchEvent.order(:id).last
    assert_equal "storefront", event.context
    assert_equal "دواء تجريبي", event.normalized_query
    assert_not event.zero_result
    assert_not SearchEvent.column_names.any? { |column| column.match?(/user|session|ip|actor/) }
  end

  test "substitution searches store a fingerprint but never the query text" do
    sign_in @pharmacist
    assert_difference "SearchEvent.count", 1 do
      get staff_substitution_candidates_path(q: "دواء تجريبي")
    end
    event = SearchEvent.order(:id).last
    assert_equal "substitution", event.context
    assert_nil event.normalized_query
    assert event.query_fingerprint.present?
  end

  test "paging through results does not inflate the recorded search count" do
    assert_difference "SearchEvent.count", 1 do
      get products_path(q: "دواء")
      get products_path(q: "دواء", page: 2)
    end
  end

  test "the search report is restricted and exports aggregate CSV" do
    get products_path(q: "دواء تجريبي")
    %i[pharmacist inventory_manager customer].each do |role|
      sign_in users(role)
      get admin_reports_search_index_path(preset: "last_30_days")
      assert_response :not_found
      sign_out users(role)
    end

    sign_in users(:order_manager)
    get admin_reports_search_index_path(preset: "last_30_days")
    assert_response :success
    assert_match "بحث المنتجات", response.body

    get admin_reports_search_index_path(preset: "last_30_days", format: :csv)
    assert_response :success
    assert_match "دواء تجريبي", response.body
  end

  private

  def rx_product(name, active: true, ingredients: [])
    record = Product.create!(name:, slug: "i-#{SecureRandom.hex(4)}", price: 60, stock_quantity: 8,
      category: @category, brand: @brand, requires_prescription: true, active:,
      sku: "IN-#{SecureRandom.hex(3).upcase}", barcode: SecureRandom.random_number(10**12).to_s.rjust(12, "2"))
    ingredients.each { |ingredient| record.product_active_ingredients.create!(active_ingredient: ingredient) }
    record.inventory_batches.create!(batch_number: "B-#{SecureRandom.hex(3)}", lot_number: "L-#{SecureRandom.hex(3)}",
      expiry_date: 1.year.from_now, received_at: Time.current, original_quantity: 8, on_hand_quantity: 8,
      reserved_quantity: 0, unit_cost_cents: 1000)
    Inventory::BatchAggregate.sync_product!(record)
    record
  end
end
