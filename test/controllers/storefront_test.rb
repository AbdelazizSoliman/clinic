require "test_helper"

class StorefrontTest < ActionDispatch::IntegrationTest
  test "homepage responds successfully" do
    get root_url
    assert_response :success
    assert_select "html[dir='rtl'][lang='ar']"
    assert_select "h1", /كل ما تحتاجه لصحتك/
  end

  test "product index responds successfully" do
    get products_url
    assert_response :success
    assert_select "h1", "تصفح المنتجات"
    assert_select "turbo-frame#products_browser"
  end

  test "product search returns matching names, brands, and categories" do
    get products_url, params: { q: "فيشي" }
    assert_response :success
    assert_select "article", count: 1
    assert_select "article", text: /كريم مرطب/
  end

  test "product filters return matching products" do
    get products_url, params: { category: "medicines", brand: "eva-pharma", discounted: "true" }
    assert_response :success
    assert_select "article", count: 1
    assert_select "[aria-label='الفلاتر النشطة']"
  end

  test "product sorting is reflected in rendered order" do
    get products_url, params: { sort: "price_desc" }
    assert_response :success
    assert_select "article h3" do |headings|
      assert_equal products(:skin_product).name, headings.first.text.strip
    end
  end

  test "product pagination preserves query parameters" do
    13.times do |index|
      Product.create!(name: "منتج #{index}", slug: "page-product-#{index}", price: index + 1, stock_quantity: 1, category: categories(:medicines), brand: brands(:eva))
    end
    get products_url, params: { available: "true" }
    assert_response :success
    assert_select "nav[aria-label='صفحات المنتجات'] a[href*='available=true']"
    assert_select "#product-results article", count: 12
  end

  test "empty search has a tailored state" do
    get products_url, params: { q: "لا-يوجد-إطلاقا" }
    assert_response :success
    assert_select "h2", /لا توجد نتائج/
  end

  test "Turbo Frame request renders browsable results" do
    get products_url, params: { available: "true" }, headers: { "Turbo-Frame" => "products_browser" }
    assert_response :success
    assert_select "turbo-frame#products_browser"
    assert_select "#product-results[aria-live='polite']"
  end

  test "active product show responds successfully" do
    get product_url(products(:featured))
    assert_response :success
    assert_select "h1", products(:featured).name
  end

  test "inactive product is not publicly visible" do
    get product_url(products(:inactive))
    assert_response :not_found
  end

  test "category page responds successfully" do
    get category_url(categories(:medicines))
    assert_response :success
    assert_select "h1", categories(:medicines).name
    assert_select "turbo-frame#products_browser"
  end

  test "category page supports brand and availability filters" do
    get category_url(categories(:medicines)), params: { brand: "eva-pharma", available: "true" }
    assert_response :success
    assert_select "article", count: 1
  end
end
