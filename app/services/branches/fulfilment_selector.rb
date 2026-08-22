module Branches
  class FulfilmentSelector
    def self.call(lines)
      quantities = lines.each_with_object(Hash.new(0)) { |line, result| result[line.product_id] += line.quantity }
      Branch.fulfilment_enabled.order(default: :desc, code: :asc).detect do |branch|
        quantities.all? do |product_id, quantity|
          InventoryBatch.where(branch:, product_id:).allocatable.sum("on_hand_quantity - reserved_quantity - returned_quarantine_quantity") >= quantity
        end
      end
    end
  end
end
