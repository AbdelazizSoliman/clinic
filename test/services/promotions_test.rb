require "test_helper"

class PromotionsTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    @product = products(:skin_product)
    @item = Struct.new(:product, :quantity).new(@product, 2)
  end

  test "calculator applies percentage product promotion with deterministic cents" do
    promotion = create_promotion(promotion_type: "product", discount_type: "percentage", discount_value: 10, automatic: true)
    promotion.products << @product
    result = Promotions::Calculator.call(items: [ @item ])
    assert_equal 50_000, result.subtotal_cents
    assert_equal 5_000, result.product_discount_cents
    assert_equal 45_000, result.total_cents
    assert_equal 22_500, result.lines.first.final_unit_price_cents
  end

  test "best price uses discount then priority and floors totals at zero" do
    weak = create_promotion(promotion_type: "product", discount_type: "fixed_amount", discount_value: 2_000, automatic: true, priority: 100)
    strong = create_promotion(promotion_type: "product", discount_type: "fixed_amount", discount_value: 60_000, automatic: true, priority: 1)
    [ weak, strong ].each { |promotion| promotion.products << @product }
    result = Promotions::Calculator.call(items: [ @item ])
    assert_equal 0, result.total_cents
    assert_equal strong, result.applied_promotions.first.promotion
  end

  test "prescription products are excluded unless explicitly enabled" do
    @product.update!(requires_prescription: true)
    promotion = create_promotion(promotion_type: "product", discount_type: "percentage", discount_value: 10, automatic: true)
    promotion.products << @product
    assert_equal 0, Promotions::Calculator.call(items: [ @item ]).discount_cents
    promotion.update!(applies_to_prescription_products: true)
    assert_operator Promotions::Calculator.call(items: [ @item ]).discount_cents, :>, 0
  end

  test "coupon application is normalized idempotent and removable" do
    promotion = create_promotion(discount_value: 5_000)
    coupon = promotion.coupons.create!(code: "save50")
    cart = carts(:customer_cart)
    result = Promotions::ApplyCoupon.new(cart:, code: " SAVE50 ", user: users(:customer)).call
    assert result.success?
    assert_equal coupon, cart.reload.applied_coupon
    assert Promotions::ApplyCoupon.new(cart:, code: "save50", user: users(:customer)).call.success?
    assert Promotions::RemoveCoupon.call(cart)
    assert_nil cart.reload.applied_coupon
  end

  test "non-stackable coupon competes with automatic promotion and best price wins" do
    automatic = create_promotion(promotion_type: "product", discount_type: "fixed_amount",
      discount_value: 2_000, automatic: true, stackable: false)
    automatic.products << @product
    coupon_promotion = create_promotion(discount_value: 6_000, stackable: false)
    coupon = coupon_promotion.coupons.create!(code: "BESTPRICE")
    result = Promotions::Calculator.call(items: [ @item ], coupon:)
    assert_equal 6_000, result.discount_cents
    assert_equal coupon_promotion, result.applied_promotions.first.promotion
  end

  test "order creation snapshots discount and cancellation releases redemption" do
    promotion = create_promotion(discount_value: 1_000)
    coupon = promotion.coupons.create!(code: "ORDER10")
    cart = carts(:customer_cart)
    cart.update!(applied_coupon: coupon, applied_coupon_code_snapshot: coupon.code,
      checkout_submission_token: SecureRandom.urlsafe_base64(32))
    result = Orders::CreateFromCart.new(user: users(:customer), cart:, address_id: addresses(:home).id,
      delivery_method: "standard", payment_method: "cash_on_delivery", submission_token: cart.checkout_submission_token).call
    assert result.success?, result.errors.inspect
    assert_equal 1_000, result.order.discount_cents
    assert_equal "ORDER10", result.order.order_promotions.first.code
    assert result.order.promotion_redemptions.first.redeemed?
    cancel = Orders::Cancel.new(order: result.order, actor: users(:customer), reason: "تغيير الرأي", source: "customer").call
    assert cancel.success?
    assert result.order.promotion_redemptions.first.reload.released?
    assert_equal 1_000, result.order.reload.discount_cents
  end

  private

  def create_promotion(**attributes)
    Promotion.create!({ name: "عرض", internal_name: SecureRandom.hex(4), promotion_type: "cart",
      discount_type: "fixed_amount", discount_value: 1_000, starts_at: 1.hour.ago, ends_at: 1.day.from_now,
      active: true, automatic: false, created_by: @admin, updated_by: @admin }.merge(attributes))
  end
end
