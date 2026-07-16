require "test_helper"

class PromotionTest < ActiveSupport::TestCase
  def build_promotion(**attributes)
    Promotion.new({ name: "خصم", internal_name: "test", promotion_type: "cart", discount_type: "percentage",
      discount_value: 10, starts_at: 1.hour.ago, ends_at: 1.day.from_now, active: true,
      created_by: users(:admin), updated_by: users(:admin) }.merge(attributes))
  end

  test "validates types schedules percentages and compatible discounts" do
    assert build_promotion.valid?
    assert_not build_promotion(discount_value: 101).valid?
    assert_not build_promotion(ends_at: 2.hours.ago).valid?
    assert_not build_promotion(discount_type: "free_delivery", promotion_type: "cart", discount_value: 0).valid?
  end

  test "effective interval uses inclusive start and exclusive end" do
    promotion = build_promotion(starts_at: Time.current, ends_at: 1.hour.from_now)
    assert promotion.effective?(promotion.starts_at)
    assert_not promotion.effective?(promotion.ends_at)
  end

  test "coupon normalizes code and enforces case insensitive uniqueness" do
    promotion = build_promotion
    promotion.save!
    coupon = promotion.coupons.create!(code: " welcome10 ")
    assert_equal "WELCOME10", coupon.reload.normalized_code
    duplicate = promotion.coupons.new(code: "welcome10")
    assert_not duplicate.valid?
  end
end
