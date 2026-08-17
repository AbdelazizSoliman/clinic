module Pos
  class Recalculate
    PricingItem = Data.define(:product, :quantity)

    def self.call(sale)
      items = sale.items.includes(product: %i[category brand]).order(:id).to_a
      included = items.reject { |item| item.prescription_review_item&.rejected? }
      pricing_items = included.map do |item|
        PricingItem.new(product: effective_product(item), quantity: item.quantity)
      end
      calculation = Promotions::Calculator.call(items: pricing_items, include_automatic: true)
      included.zip(calculation.lines).each do |item, line|
        item.update!(unit_price_cents: line.final_unit_price_cents,
          discount_cents: line.discount_cents, line_total_cents: line.line_total_cents)
      end
      (items - included).each do |item|
        item.update!(unit_price_cents: 0, discount_cents: 0, line_total_cents: 0)
      end
      automatic = calculation.discount_cents
      manual = [ sale.manual_discount_cents, calculation.subtotal_cents - automatic ].min
      sale.update!(subtotal_cents: calculation.subtotal_cents, automatic_discount_cents: automatic,
        manual_discount_cents: manual, tax_cents: 0,
        total_cents: calculation.subtotal_cents - automatic - manual,
        pricing_calculation_version: calculation.calculation_version)
      sale
    end

    def self.effective_product(item)
      review_item = item.prescription_review_item
      review_item&.dispensable? ? review_item.effective_product : item.product
    end
  end
end
