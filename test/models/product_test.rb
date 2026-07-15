require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "is valid with required attributes" do
    product = Product.new(name: "منتج", slug: "valid-product", price: 20, stock_quantity: 1, category: categories(:medicines), brand: brands(:eva))
    assert product.valid?
  end

  test "requires core fields and associations" do
    product = Product.new
    assert_not product.valid?
    %i[name slug price category brand].each { |attribute| assert product.errors[attribute].any? }
  end

  test "rejects negative price and stock" do
    product = products(:featured)
    product.assign_attributes(price: -1, stock_quantity: -1)
    assert_not product.valid?
  end

  test "compare at price must exceed current price" do
    product = products(:featured)
    product.compare_at_price = product.price
    assert_not product.valid?
  end

  test "calculates discount percentage" do
    assert_equal 18, products(:featured).discount_percentage
  end
end
