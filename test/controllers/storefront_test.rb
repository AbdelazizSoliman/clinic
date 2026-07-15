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
    assert_select "h1", "كل المنتجات"
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
  end
end
