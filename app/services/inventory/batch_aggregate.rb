module Inventory
  class BatchAggregate
    def self.sync_product!(product)
      total = product.inventory_batches.sum(:on_hand_quantity)
      product.update!(stock_quantity: total) unless product.stock_quantity == total
      total
    end

    def self.consistent?(product)
      product.stock_quantity == product.inventory_batches.sum(:on_hand_quantity)
    end
  end
end
