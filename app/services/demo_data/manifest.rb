module DemoData
  Manifest = Data.define(:accounts, :categories, :brands, :products, :inventory_movements, :customers,
    :prescriptions, :orders, :promotions, :coupons, :delivery_zones) do
    def to_h
      members.index_with { |member| public_send(member) }
    end
  end
end
