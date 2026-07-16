module Addresses
  class Deactivate
    def initialize(address)
      @address = address
    end

    def call
      Address.transaction do
        was_default = @address.default?
        @address.update!(active: false, default: false)
        replacement = @address.user.addresses.where(active: true).order(:created_at).first
        Addresses::SetDefault.new(replacement).call if was_default && replacement
      end
      true
    end
  end
end
