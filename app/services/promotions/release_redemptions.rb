module Promotions
  class ReleaseRedemptions
    def self.call(order)
      order.promotion_redemptions.redeemed.find_each(&:release!)
      true
    end
  end
end
