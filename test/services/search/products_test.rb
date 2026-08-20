require "test_helper"

class Search::ProductsTest < ActiveSupport::TestCase
  setup do
    @category = categories(:medicines)
    @brand = brands(:eva)
    @ingredient = ActiveIngredient.create!(code: "ALFA", name: "ألفازين")
    @panadol = product("بانادول أدفانس 500 مجم", sku: "PH-0100", barcode: "6220000000100",
      strength: "500 مجم", ingredients: [ @ingredient ])
    @cream = product("كريم مرطب لليدين", sku: "PH-0200", barcode: "6220000000200")
    @other = product("شامبو يومى للشعر", sku: "PH-0300", barcode: "6220000000300")
  end

  # ---------- exact identifier priority ----------

  test "an exact barcode outranks every textual match" do
    decoy = product("6220000000100 عبوة مشابهة")
    result = search(@panadol.barcode)
    assert_equal @panadol, result.records.first
    assert_equal @panadol, result.exact_identifier_match
    assert_includes result.records, decoy
  end

  test "an exact SKU is case-insensitive and outranks fuzzy names" do
    product("منتج باسم ph 0100 مشابه")
    result = search("ph-0100")
    assert_equal @panadol, result.records.first
    assert_equal @panadol, result.exact_identifier_match
  end

  test "a barcode is never fuzzily confused with a neighbouring barcode" do
    result = search("6220000000200")
    assert_equal @cream, result.exact_identifier_match
    assert_not_includes result.records, @panadol
  end

  test "identifiers typed with arabic-indic digits still match exactly" do
    assert_equal @panadol, search("٦٢٢٠٠٠٠٠٠٠١٠٠").exact_identifier_match
  end

  # ---------- ranking ----------

  test "exact name outranks prefix, which outranks a token match elsewhere in the record" do
    exact = product("زنك")
    prefix = product("زنك بلس 20 قرص")
    token_only = product("مكمل غذائي", slug_hint: "زنك".dup && "supplement", manufacturer: "معمل زنك للأدوية")
    ranked = search("زنك").records
    assert_equal [ exact, prefix ], ranked.first(2)
    assert_operator ranked.index(prefix), :<, ranked.index(token_only)
  end

  test "unrelated products never appear in results" do
    assert_not_includes search("بانادول").records, @other
    assert_not_includes search("شامبو").records, @panadol
  end

  test "ordering is stable and deterministic across repeated runs" do
    twins = 3.times.map { product("مسكن مكرر") }
    first = search("مسكن").records.map(&:id)
    3.times { assert_equal first, search("مسكن").records.map(&:id) }
    twin_positions = twins.map { |twin| first.index(twin.id) }
    assert_equal twin_positions.sort, twin_positions, "identical names tie-break on id ascending"
    assert_equal twins.map(&:id).sort, twins.map(&:id).sort_by { |id| first.index(id) }
  end

  # ---------- token matching ----------

  test "a multi-token query may satisfy tokens across different fields" do
    assert_includes search("بانادول 500").records, @panadol
    assert_includes search("بانادول #{@brand.name}").records, @panadol
    assert_includes search("#{@ingredient.name} 500").records, @panadol
  end

  test "arabic name plus english token matches" do
    latin = product("فيتامين ج 500", slug_hint: "vitamin-c-500")
    assert_includes search("فيتامين vitamin").records, latin
  end

  # ---------- ingredient ----------

  test "structured active ingredient search finds its products without duplicates" do
    twin = product("دواء آخر بنفس المادة", ingredients: [ @ingredient ])
    records = search(@ingredient.name).records
    assert_includes records, @panadol
    assert_includes records, twin
    assert_equal records.map(&:id).uniq, records.map(&:id)
  end

  test "an inactive ingredient link stops matching" do
    @panadol.product_active_ingredients.update_all(active: false)
    assert_not_includes search(@ingredient.name).records, @panadol
  end

  # ---------- normalization in matching ----------

  test "alternate arabic spellings find the stored product" do
    stored = product("شراب إبراهيم للأطفال")
    assert_includes search("شراب ابراهيم").records, stored
    assert_includes search("شراب إبراهيم").records, stored
    assert_includes search("يومى").records, @other, "a maqsura query finds the ya spelling"
    assert_includes search("يومي").records, @other
  end

  # ---------- typo tolerance ----------

  test "a one character typo still finds the product" do
    assert_includes search("بنادول").records, @panadol
  end

  test "an excessive typo returns nothing rather than arbitrary products" do
    assert_empty search("زززززززز").records
  end

  test "short queries never trigger fuzzy noise" do
    assert_empty search("ب").records, "single characters are below the minimum length"
    two_char = search("كر").records
    assert(two_char.all? { |product| product.search_name.include?("كر") }, "short queries stay prefix/token exact")
  end

  private

  def search(term, context: :staff) = Search::Products.call(query: term, context:)

  def product(name, sku: nil, barcode: nil, strength: nil, ingredients: [], slug_hint: nil, manufacturer: nil)
    record = Product.create!(name:, slug: "#{slug_hint || 'p'}-#{SecureRandom.hex(4)}", price: 50,
      stock_quantity: 5, category: @category, brand: @brand, sku:, barcode:, strength:, manufacturer:, active: true)
    ingredients.each { |ingredient| record.product_active_ingredients.create!(active_ingredient: ingredient) }
    record
  end
end
