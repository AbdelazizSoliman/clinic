module Checkout
  class DeliveryAreaPolicy
    SUPPORTED_GOVERNORATES = %w[القاهرة الجيزة].freeze

    def self.supported?(address)
      address.present? && SUPPORTED_GOVERNORATES.include?(address.governorate)
    end
  end
end
