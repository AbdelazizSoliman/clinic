require "test_helper"

class Search::ContextsTest < ActiveSupport::TestCase
  setup do
    @category = categories(:medicines)
    @brand = brands(:eva)
    @sellable = rx_product("دواء متاح للصرف", batch: :allocatable)
    @expired_only = rx_product("دواء بتشغيلة منتهية", batch: :expired)
    @quarantined_only = rx_product("دواء بتشغيلة معزولة", batch: :quarantined)
    @inactive = rx_product("دواء موقوف", batch: :allocatable, active: false)
    @otc = product("دواء بدون روشتة", requires_prescription: false)
  end

  # ---------- storefront ----------

  test "storefront hides inactive products and products of inactive lookups" do
    records = Search::Products.call(query: "دواء", context: :storefront).records
    assert_includes records, @otc
    assert_not_includes records, @inactive

    @brand.update!(active: false)
    assert_empty Search::Products.call(query: "دواء", context: :storefront).records
  end

  test "storefront search preserves category, brand, price filters, sorting and pagination" do
    other_category = Category.create!(name: "قسم آخر", slug: "other-cat", search_name: "قسم اخر")
    outside = product("دواء في قسم آخر", requires_prescription: false)
    outside.update!(category: other_category)

    filtered = ProductsQuery.new(Product.publicly_available, { "q" => "دواء", "category" => @category.slug }).call
    assert_includes filtered, @otc
    assert_not_includes filtered, outside

    sorted = ProductsQuery.new(Product.publicly_available, { "q" => "دواء", "sort" => "name" }).call
    assert_equal sorted.map(&:name).sort, sorted.map(&:name), "an explicit sort overrides relevance ordering"

    assert_empty ProductsQuery.new(Product.publicly_available, { "q" => "دواء", "min_price" => "9999" }).call
  end

  test "browsing without a query is untouched by the search engine" do
    all_products = ProductsQuery.new(Product.publicly_available, {}).call
    assert_includes all_products, @otc
    assert_includes all_products, @sellable
    assert_not_includes all_products, @inactive
  end

  # ---------- pos ----------

  test "pos search excludes inactive products but still shows unsellable stock states" do
    records = Search::Products.call(query: "دواء", context: :pos).records
    assert_includes records, @sellable
    assert_includes records, @expired_only, "POS must see the product to explain why it cannot be sold"
    assert_not_includes records, @inactive
    assert_not @expired_only.available?, "expired-only stock is never sellable"
  end

  test "pos exact barcode resolves immediately and outranks text matches" do
    result = Search::Products.call(query: @sellable.barcode, context: :pos)
    assert_equal @sellable, result.records.first
    assert_equal @sellable, result.exact_identifier_match
  end

  # ---------- substitution ----------

  test "substitution only offers active prescription products with allocatable stock" do
    records = Search::Products.call(query: "دواء", context: :substitution).records
    assert_includes records, @sellable
    assert_not_includes records, @expired_only
    assert_not_includes records, @quarantined_only
    assert_not_includes records, @inactive
    assert_not_includes records, @otc, "a non-prescription product is not a prescription substitute"
  end

  test "substitution search returns products without asserting equivalence" do
    result = Search::Products.call(query: "دواء", context: :substitution)
    assert result.records.all? { |product| product.is_a?(Product) }
    assert_not result.respond_to?(:equivalent_products)
    assert_not result.respond_to?(:recommended_substitute)
  end

  # ---------- staff ----------

  test "staff search may see inactive products" do
    assert_includes Search::Products.call(query: "دواء", context: :staff).records, @inactive
    assert_includes Admin::ProductsQuery.new(Product.all, { q: "دواء" }).call, @inactive
  end

  test "admin search finds a product by exact sku and barcode" do
    assert_includes Admin::ProductsQuery.new(Product.all, { q: @sellable.sku.downcase }).call, @sellable
    assert_includes Admin::ProductsQuery.new(Product.all, { q: @sellable.barcode }).call, @sellable
  end

  # ---------- bounds ----------

  test "result limits are bounded and queries are length-capped" do
    result = Search::Products.call(query: "دواء", context: :storefront, limit: 9_999)
    assert_operator result.limit, :<=, Search::Products::MAX_LIMIT
    assert_operator Search::Query.parse("ا" * 5_000).normalized.length, :<=, Search::ArabicNormalizer::MAX_LENGTH
  end

  test "a blank or too short query returns nothing rather than the whole catalogue" do
    assert_empty Search::Products.call(query: "", context: :storefront).records
    assert_empty Search::Products.call(query: "   ", context: :storefront).records
    assert_empty Search::Products.call(query: "د", context: :storefront).records
  end

  private

  def product(name, requires_prescription: true, active: true)
    Product.create!(name:, slug: "s-#{SecureRandom.hex(4)}", price: 40, stock_quantity: 5,
      category: @category, brand: @brand, requires_prescription:, active:,
      sku: "SK-#{SecureRandom.hex(3).upcase}", barcode: SecureRandom.random_number(10**12).to_s.rjust(12, "1"))
  end

  def rx_product(name, batch:, active: true)
    record = product(name, active:)
    attributes = { batch_number: "B-#{SecureRandom.hex(3)}", lot_number: "L-#{SecureRandom.hex(3)}",
      received_at: Time.current, original_quantity: 10, on_hand_quantity: 10, reserved_quantity: 0,
      unit_cost_cents: 1000, expiry_date: 1.year.from_now }
    case batch
    when :expired then attributes[:expiry_date] = Date.yesterday
    when :quarantined then attributes.merge!(quarantined_at: Time.current, quarantine_reason: "عزل اختبار",
      quarantined_by: users(:inventory_manager))
    end
    record.inventory_batches.create!(attributes)
    Inventory::BatchAggregate.sync_product!(record)
    record
  end
end
