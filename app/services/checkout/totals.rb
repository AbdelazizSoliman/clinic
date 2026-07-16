module Checkout
  class Totals
    def self.call(items, zone: nil, delivery_method: nil, user: nil, coupon: nil, now: Time.current)
      Promotions::Calculator.call(items:, user:, coupon:, zone:, delivery_method:, now:)
    end
  end
end
