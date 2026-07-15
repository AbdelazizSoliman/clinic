require "test_helper"

class BrandTest < ActiveSupport::TestCase
  test "requires a unique name and slug" do
    duplicate = Brand.new(name: brands(:eva).name, slug: brands(:eva).slug)
    assert_not duplicate.valid?
    assert duplicate.errors[:name].any?
    assert duplicate.errors[:slug].any?
  end
end
