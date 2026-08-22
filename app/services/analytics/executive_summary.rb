module Analytics
  class ExecutiveSummary
    def initialize(range:, branches: nil)
      @range = range
      @branches = Array(branches).compact
    end

    def call
      online = scoped(Order.where(created_at: @range.from..@range.to).where.not(status: %i[cancelled rejected]))
      pos = scoped(PosSale.completed.where(completed_at: @range.from..@range.to))
      returns = scoped(ReturnRequest.where(created_at: @range.from..@range.to))
      batches = scoped(InventoryBatch.all)
      online_cents = online.sum(:total_cents)
      pos_cents = pos.sum(:total_cents)
      refund_cents = Refund.where(created_at: @range.from..@range.to, status: Refund.statuses[:completed]).sum(:amount_cents)
      {
        gross_sales_cents: online_cents + pos_cents,
        net_sales_cents: online_cents + pos_cents - refund_cents,
        refunds_cents: refund_cents,
        transaction_count: online.count + pos.count,
        average_transaction_cents: average(online_cents + pos_cents, online.count + pos.count),
        online_sales_cents: online_cents,
        pos_sales_cents: pos_cents,
        return_count: returns.count,
        inventory_units: batches.sum(:on_hand_quantity),
        available_units: batches.sum("on_hand_quantity - reserved_quantity - returned_quarantine_quantity"),
        inventory_value_cents: batches.sum("on_hand_quantity * unit_cost_cents"),
        expired_units: batches.expired.sum(:on_hand_quantity),
        near_expiry_units: batches.near_expiry(days: 90).sum(:on_hand_quantity),
        wallet_liability_cents: WalletLedgerEntry.sum(WalletLedgerEntry.balance_sql),
        loyalty_points_outstanding: LoyaltyLedgerEntry.sum(LoyaltyLedgerEntry.balance_sql),
        branches: branch_rows
      }
    end

    private

    def scoped(relation)
      @branches.any? && relation.klass.column_names.include?("branch_id") ? relation.where(branch_id: @branches.map(&:id)) : relation
    end

    def average(total, count) = count.zero? ? 0 : (total.to_f / count).round

    def branch_rows
      Branch.active.order(:code).filter_map do |branch|
        next if @branches.any? && !@branches.include?(branch)
        online = Order.where(branch:, created_at: @range.from..@range.to).where.not(status: %i[cancelled rejected]).sum(:total_cents)
        pos = PosSale.completed.where(branch:, completed_at: @range.from..@range.to).sum(:total_cents)
        { id: branch.id, code: branch.code, name: branch.display_name, sales_cents: online + pos,
          inventory_units: InventoryBatch.where(branch:).sum(:on_hand_quantity) }
      end
    end
  end
end
