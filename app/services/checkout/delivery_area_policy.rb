module Checkout
  class DeliveryAreaPolicy
    def self.supported?(address)
      Delivery::ZoneMatcher.call(address).matched?
    end
  end
end
