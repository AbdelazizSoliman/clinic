require "test_helper"

# The ranking expression is the only place the search domain hands PostgreSQL a literal
# SQL string (ORDER BY cannot take bind parameters here). These tests prove that every
# value inside it is escaped by `sanitize_sql_array` before it reaches the database.
class Search::InjectionSafetyTest < ActiveSupport::TestCase
  ATTACKS = [
    "'; DROP TABLE products; --",
    "' OR '1'='1",
    "%' OR 1=1 --",
    "\\'; DELETE FROM users WHERE '1'='1",
    "بانادول'); DROP TABLE brands; --",
    "1' UNION SELECT encrypted_password FROM users --"
  ].freeze

  setup do
    @product = Product.create!(name: "بانادول أدفانس", slug: "inj-#{SecureRandom.hex(4)}", price: 20,
      stock_quantity: 3, category: categories(:medicines), brand: brands(:eva))
  end

  test "injection attempts are treated as literal text and change no data" do
    ATTACKS.each do |attack|
      before = [ Product.count, User.count, Brand.count ]
      result = Search::Products.call(query: attack, context: :staff)
      assert_kind_of Array, result.records
      assert_equal before, [ Product.count, User.count, Brand.count ], "#{attack} must not modify data"
    end
    assert_predicate Product, :any?
    assert_predicate User, :any?
  end

  test "quotes and wildcards are escaped in both the predicate and the ordering" do
    ATTACKS.each do |attack|
      service = Search::Products.new(query: attack, context: :staff)
      sql = service.relation.reorder(*service.rank_ordering).to_sql
      assert_no_match(/DROP TABLE/i, sql.gsub(/'[^']*'/, "'?'"), "attack text must live only inside quoted literals")
      assert_nothing_raised { ActiveRecord::Base.connection.select_all(sql) }
    end
  end

  test "a LIKE wildcard in the query cannot widen the match" do
    Product.create!(name: "منتج مختلف تمامًا", slug: "other-#{SecureRandom.hex(4)}", price: 20,
      stock_quantity: 3, category: categories(:medicines), brand: brands(:eva))
    records = Search::Products.call(query: "%%%%", context: :staff).records
    assert_not_includes records, @product, "wildcards are escaped, not honoured"
  end

  test "search analytics never persist raw markup or unbounded text" do
    result = Search::Products.call(query: "<script>alert(1)</script>", context: :storefront)
    event = Search::RecordEvent.call(result:)
    assert event
    assert_operator event.normalized_query.length, :<=, 120
    assert_not_includes event.normalized_query, "<"
    assert_not_includes event.normalized_query, ">"
  end
end
