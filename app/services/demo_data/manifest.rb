module DemoData
  Manifest = Data.define(:accounts, :categories, :brands, :products, :inventory_movements, :customers,
    :prescriptions, :orders, :promotions, :coupons, :delivery_zones, :suppliers, :purchase_orders, :purchase_receipts,
    :cashier_sessions, :pos_sales, :active_ingredients, :safety_rules, :safety_findings) do
    def to_h
      members.index_with { |member| public_send(member) }
    end
  end
end
