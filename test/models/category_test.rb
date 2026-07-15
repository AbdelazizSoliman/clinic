require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "is valid with valid attributes" do
    assert Category.new(name: "قسم جديد", slug: "new-category").valid?
  end

  test "requires a unique name and slug" do
    duplicate = Category.new(name: categories(:medicines).name, slug: categories(:medicines).slug)
    assert_not duplicate.valid?
    assert duplicate.errors[:name].any?
    assert duplicate.errors[:slug].any?
  end

  test "requires a URL-safe slug" do
    assert_not Category.new(name: "قسم", slug: "Not Valid").valid?
  end
end
