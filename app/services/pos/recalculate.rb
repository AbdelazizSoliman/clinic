module Pos
  class Recalculate
    def self.call(sale)
      items = sale.items.includes(product: %i[category brand]).order(:id).to_a
      calculation = Promotions::Calculator.call(items:, include_automatic: true)
      by_product = calculation.lines.index_by { |line| line.product.id }
      items.each do |item|
        line = by_product.fetch(item.product_id)
        item.update!(product_name: item.product.name, product_sku: item.product.sku,
          product_barcode: item.product.barcode, original_unit_price_cents: line.original_unit_price_cents,
          unit_price_cents: line.final_unit_price_cents, discount_cents: line.discount_cents,
          line_total_cents: line.line_total_cents, requires_prescription: item.product.requires_prescription?)
      end
      automatic = calculation.discount_cents
      manual = [ sale.manual_discount_cents, calculation.subtotal_cents - automatic ].min
      sale.update!(subtotal_cents: calculation.subtotal_cents, automatic_discount_cents: automatic,
        manual_discount_cents: manual, tax_cents: 0,
        total_cents: calculation.subtotal_cents - automatic - manual,
        pricing_calculation_version: calculation.calculation_version)
      sale
    end
  end
end
