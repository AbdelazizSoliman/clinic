module Addresses
  class Save
    def initialize(address:, attributes:)
      @address = address
      @attributes = attributes
    end

    def call
      Address.transaction do
        make_default = ActiveModel::Type::Boolean.new.cast(@attributes[:default])
        @address.assign_attributes(@attributes.except(:default))
        @address.default = make_default || !@address.user.addresses.where(active: true).where.not(id: @address.id).exists?
        @address.user.addresses.where(active: true, default: true).where.not(id: @address.id).update_all(default: false) if @address.default?
        @address.save!
      end
      @address
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
