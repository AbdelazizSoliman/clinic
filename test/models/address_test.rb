require "test_helper"

class AddressTest < ActiveSupport::TestCase
  def valid_attributes
    { label: " منزل ", recipient_name: " أحمد  محمد ", mobile_number: "01012345678", governorate: "القاهرة", city: "المعادي", street: "شارع 9", building_number: "12", active: true }
  end

  test "requires delivery essentials and validates coordinates" do
    address = users(:customer).addresses.new
    assert_not address.valid?
    address.assign_attributes(valid_attributes.merge(latitude: 91, longitude: -181))
    assert_not address.valid?
  end

  test "first active address becomes default and normalizes whitespace" do
    user = users(:admin)
    address = user.addresses.new
    assert Addresses::Save.new(address:, attributes: valid_attributes).call
    assert address.default?
    assert_equal "منزل", address.label
    assert_equal "أحمد محمد", address.recipient_name
  end

  test "setting default reassigns transactionally" do
    assert Addresses::SetDefault.new(addresses(:office)).call
    assert addresses(:office).reload.default?
    assert_not addresses(:home).reload.default?
  end

  test "deactivating default promotes another active address" do
    Addresses::Deactivate.new(addresses(:home)).call
    assert_not addresses(:home).reload.active?
    assert addresses(:office).reload.default?
  end

  test "database prevents two active defaults" do
    assert_raises ActiveRecord::RecordNotUnique do
      Address.where(id: addresses(:office).id).update_all(default: true)
    end
  end
end
