module Promotions
  class RemoveCoupon
    def self.call(cart)
      cart.with_lock { cart.clear_coupon! if cart.applied_coupon_id }
      true
    end
  end
end
