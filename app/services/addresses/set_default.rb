module Addresses
  class SetDefault
    def initialize(address)
      @address = address
    end

    def call
      return false unless @address.active?

      Address.transaction do
        @address.user.addresses.where(active: true, default: true).where.not(id: @address.id).update_all(default: false)
        @address.update!(default: true)
      end
      true
    end
  end
end
