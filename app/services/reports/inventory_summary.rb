module Reports
  class InventorySummary
    AVAILABLE_SQL = <<~SQL.squish.freeze
      products.stock_quantity - (
        SELECT COALESCE(SUM(quantity), 0)
        FROM inventory_reservations
        WHERE inventory_reservations.product_id = products.id AND status = 0
      )
    SQL
    Result = Data.define(:cards, :movement_totals, :warnings, :recent_movements)
    def initialize(range) = @range = range
    def call
      physical = Product.sum(:stock_quantity)
      reserved = InventoryReservation.active.sum(:quantity)
      movements = InventoryMovement.where(created_at: @range.range)
      Result.new(cards: { physical:, reserved:, available: physical - reserved,
        low_stock: Product.where("#{AVAILABLE_SQL} > 0 AND #{AVAILABLE_SQL} <= products.low_stock_threshold").count,
        out_of_stock: Product.where("#{AVAILABLE_SQL} <= 0").count },
        movement_totals: movements.group(:movement_type).sum(:quantity_delta), warnings: warnings,
        recent_movements: movements.includes(:product, :actor).order(created_at: :desc).limit(20))
    end
    private
    def warnings
      {
        negative_availability: Product.where("stock_quantity < (SELECT COALESCE(SUM(quantity), 0) FROM inventory_reservations WHERE inventory_reservations.product_id = products.id AND status = ?)", InventoryReservation.statuses[:active]).count,
        inconsistent_movements: InventoryMovement.where("quantity_after <> quantity_before + quantity_delta").count,
        delivered_with_active_reservations: Order.delivered.joins(:inventory_reservations).merge(InventoryReservation.active).distinct.count,
        terminal_with_active_reservations: Order.where(status: %i[cancelled rejected]).joins(:inventory_reservations).merge(InventoryReservation.active).distinct.count
      }
    end
  end
end
