module Reports
  class BatchInventorySummary
    Result = Data.define(:cards, :expired, :near_expiry, :quarantined, :batches, :valuation_cents, :fefo_exceptions)

    def initialize(range, threshold_days: PharmacySetting.current.near_expiry_threshold_days || 90)
      @range, @threshold_days = range, threshold_days.to_i
    end

    def call
      scope = InventoryBatch.includes(:product, :supplier, :purchase_receipt).order(:expiry_date, :received_at, :id)
      expired = scope.expired
      near = scope.near_expiry(days: @threshold_days)
      quarantined = scope.where.not(quarantined_at: nil)
      Result.new(cards: {
        batches: scope.count, physical: scope.sum(:on_hand_quantity), reserved: scope.sum(:reserved_quantity),
        available: scope.allocatable.sum("on_hand_quantity - reserved_quantity"),
        expired: expired.sum(:on_hand_quantity), near_expiry: near.sum(:on_hand_quantity),
        quarantined: quarantined.sum(:on_hand_quantity)
      }, expired:, near_expiry: near, quarantined:, batches: scope,
        valuation_cents: scope.sum("on_hand_quantity * COALESCE(unit_cost_cents, 0)"),
        fefo_exceptions: fefo_exceptions)
    end

    private

    def fefo_exceptions
      InventoryReservationAllocation.joins(:inventory_batch, inventory_reservation: :order)
        .where(inventory_reservations: { created_at: @range.range })
        .where("inventory_batches.expiry_date < ?", Date.current)
    end
  end
end
