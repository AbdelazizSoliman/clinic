require "test_helper"

class ProductsQueryTest < ActiveSupport::TestCase
  setup do
    @medicine = products(:featured)
    @skin_product = products(:skin_product)
  end

  test "searches by product name" do
    assert_equal [ @medicine ], query(q: "بانادول").to_a
  end

  test "searches by brand name" do
    assert_includes query(q: brands(:vichy).name), @skin_product
  end

  test "searches by category name" do
    assert_includes query(q: categories(:skin_care).name), @skin_product
  end

  test "searches by short description" do
    assert_includes query(q: "ترطيب يومي"), @skin_product
  end

  test "filters by category slug" do
    assert_equal [ @skin_product ], query(category: "skin-care").to_a
  end

  test "filters by brand slug" do
    assert_equal [ @skin_product ], query(brand: "vichy").to_a
  end

  test "filters by price range" do
    assert_equal [ @skin_product ], query(min_price: "200", max_price: "300").to_a
  end

  test "returns no products for an inverted price range" do
    products_query = ProductsQuery.new(Product.active, min_price: "300", max_price: "100")
    assert products_query.invalid_price_range?
    assert_empty products_query.call
  end

  test "filters discounted products" do
    assert_equal [ @medicine ], query(discounted: "true").to_a
  end

  test "filters available products" do
    assert_not_includes query(available: "true"), products(:inactive)
    assert query(available: "true").all?(&:available?)
  end

  test "filters prescription products" do
    prescription = create_product(slug: "prescription", requires_prescription: true)
    assert_equal [ prescription ], query(prescription: "true").to_a
  end

  test "filters featured products" do
    assert_equal [ @medicine ], query(featured: "true").to_a
  end

  test "sorts by each supported option" do
    cheap = create_product(name: "ألف", slug: "cheap", price: 10, compare_at_price: 20)
    expensive = create_product(name: "ياء", slug: "expensive", price: 500, compare_at_price: 550)

    assert_equal cheap, query(sort: "price_asc").first
    assert_equal expensive, query(sort: "price_desc").first
    assert_equal cheap, query(sort: "discount_desc").first
    assert_equal cheap, query(sort: "name").first
    assert_equal expensive, query(sort: "newest").first
    assert_equal @medicine, query(sort: "recommended").first
  end

  test "falls back safely for an invalid sort" do
    assert_equal query(sort: "recommended").pluck(:id), query(sort: "DROP TABLE products").pluck(:id)
  end

  test "combines filters" do
    result = query(category: "medicines", brand: "eva-pharma", discounted: "true", available: "true")
    assert_equal [ @medicine ], result.to_a
  end

  private

  def query(params)
    ProductsQuery.new(Product.active, params).call
  end

  def create_product(attributes = {})
    defaults = {
      name: "منتج إضافي", price: 100, stock_quantity: 5, active: true,
      featured: false, requires_prescription: false,
      category: categories(:medicines), brand: brands(:eva)
    }
    Product.create!(defaults.merge(attributes))
  end
end
