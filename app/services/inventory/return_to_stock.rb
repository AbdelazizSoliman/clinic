module Inventory
  class ReturnToStock
    def self.call(product:, actor:, quantity:, reason:, reference:, idempotency_key:)
      return false unless actor&.can_manage_inventory? && quantity.to_i.positive? && reason.present? && reference && idempotency_key.present?
      InventoryMovement.transaction do
        return true if InventoryMovement.exists?(idempotency_key:)
        product.lock!
        before = product.stock_quantity
        product.update!(stock_quantity: before + quantity.to_i)
        product.inventory_movements.create!(actor:, movement_type: :return_to_stock, quantity_delta: quantity.to_i,
          quantity_before: before, quantity_after: product.stock_quantity, reason:, reference:, idempotency_key:)
      end
      true
    end
  end
end
