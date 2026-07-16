require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "defaults to customer role" do
    user = User.new(email: "new@example.com", password: "password123", first_name: "أحمد", last_name: "علي", mobile_number: "01011111111")
    assert user.customer?
    assert user.valid?
  end

  test "validates role and profile fields" do
    user = users(:customer)
    user.assign_attributes(first_name: "", mobile_number: "invalid")
    assert_not user.valid?
    assert user.errors[:first_name].any?
    assert user.errors[:mobile_number].any?
  end

  test "inactive user cannot authenticate" do
    assert_not users(:inactive).active_for_authentication?
    assert_equal :inactive_account, users(:inactive).inactive_message
  end
end
