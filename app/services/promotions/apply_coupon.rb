module Promotions
  class ApplyCoupon
    Result = Data.define(:success?, :cart, :calculation, :error_code)
    def initialize(cart:, code:, user: nil)
      @cart, @code, @user = cart, code.to_s.strip.upcase, user
    end
    def call
      coupon = Coupon.includes(promotion: %i[products categories brands excluded_products redemptions]).find_by(normalized_code: @code)
      return failure(:invalid) unless coupon
      result = Promotions::Eligibility.new(promotion: coupon.promotion, coupon:, items: @cart.items.includes(product: %i[category brand]), user: @user).call
      return failure(:invalid) unless result.eligible?
      @cart.with_lock { @cart.update!(applied_coupon: coupon, applied_coupon_code_snapshot: coupon.code) }
      calculation = Promotions::Calculator.call(items: @cart.items.includes(product: %i[category brand]), user: @user, coupon:)
      Result.new(success?: true, cart: @cart, calculation:, error_code: nil)
    end
    private
    def failure(code) = Result.new(success?: false, cart: @cart, calculation: nil, error_code: code)
  end
end
