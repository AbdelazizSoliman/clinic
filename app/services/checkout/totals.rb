module Checkout
  class Totals
    Line = Data.define(:product, :quantity, :unit_price_cents, :compare_at_price_cents, :discount_cents, :line_total_cents)
    Result = Data.define(:lines, :subtotal_cents, :discount_cents, :delivery_fee_cents, :total_cents)

    def self.call(items)
      lines = items.map do |item|
        unit = (item.product.price * 100).round
        compare = (item.product.compare_at_price * 100).round if item.product.compare_at_price
        Line.new(product: item.product, quantity: item.quantity, unit_price_cents: unit, compare_at_price_cents: compare, discount_cents: compare ? [ compare - unit, 0 ].max * item.quantity : 0, line_total_cents: unit * item.quantity)
      end
      subtotal = lines.sum(&:line_total_cents)
      Result.new(lines:, subtotal_cents: subtotal, discount_cents: 0, delivery_fee_cents: 0, total_cents: subtotal)
    end
  end
end
