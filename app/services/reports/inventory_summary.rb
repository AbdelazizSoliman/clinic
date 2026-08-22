module Reports
  class InventorySummary
    Result = Data.define(:cards, :movement_totals, :warnings, :recent_movements)
    def initialize(range) = @range = range
    def call
      physical = InventoryBatch.sum(:on_hand_quantity)
      reserved = InventoryBatch.sum(:reserved_quantity)
      movements = InventoryMovement.where(created_at: @range.range)
      products = Product.pluck(:id, :low_stock_threshold)
      available = eligible_batches.group(:product_id)
        .sum("on_hand_quantity - reserved_quantity - returned_quarantine_quantity")
      Result.new(cards: { physical:, reserved:, available: physical - reserved,
        low_stock: products.count { |id, threshold| available.fetch(id, 0).between?(1, threshold) },
        out_of_stock: products.count { |id, _threshold| available.fetch(id, 0) <= 0 } },
        movement_totals: movements.group(:movement_type).sum(:quantity_delta), warnings: warnings,
        recent_movements: movements.includes(:product, :actor).order(created_at: :desc).limit(20))
    end
    private
    def eligible_batches
      scope = InventoryBatch.where(expiry_date: Date.current..).where(quarantined_at: nil)
      Current.branch_scope ? scope.where(branch: Current.branch_scope) : scope
    end

    def warnings
      {
        negative_availability: InventoryBatch.where("reserved_quantity > on_hand_quantity").count,
        product_batch_mismatch: Current.branch_scope ? 0 : Product.where("stock_quantity <> (SELECT COALESCE(SUM(on_hand_quantity), 0) FROM inventory_batches WHERE inventory_batches.product_id = products.id AND inventory_batches.organization_id = products.organization_id)").count,
        inconsistent_movements: InventoryMovement.where("quantity_after <> quantity_before + quantity_delta").count,
        delivered_with_active_reservations: Order.delivered.joins(:inventory_reservations).merge(InventoryReservation.active).distinct.count,
        terminal_with_active_reservations: Order.where(status: %i[cancelled rejected]).joins(:inventory_reservations).merge(InventoryReservation.active).distinct.count
      }
    end
  end
end
