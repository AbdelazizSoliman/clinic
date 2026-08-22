module Analytics
  class AdvancedSummary
    def initialize(range:, branches: nil)
      @range = range
      @branches = Array(branches).compact
      @branch_ids = @branches.map(&:id)
    end

    def call
      { sales: sales, purchasing: purchasing, inventory: inventory, customers: customers,
        prescriptions: prescriptions, safety: safety, search: search, loyalty: loyalty,
        wallet: wallet, returns: returns, branches: branches, comparison: comparison }
    end

    private

    def sales
      orders = branch_scope(Order.where(created_at: period).where.not(status: %i[cancelled rejected]))
      pos = branch_scope(PosSale.completed.where(completed_at: period))
      order_items = OrderItem.joins(:order).merge(orders)
      pos_items = PosSaleItem.joins(:pos_sale).merge(pos)
      gross = orders.sum(:subtotal_cents) + pos.sum(:subtotal_cents)
      refunds = Refund.completed.where(refunded_at: period).sum(:amount_cents)
      count = orders.count + pos.count
      {
        gross_cents: gross, net_cents: gross - refunds, refunds_cents: refunds,
        online_count: orders.count, pos_count: pos.count, average_transaction_cents: count.zero? ? 0 : ((gross - refunds).to_f / count).round,
        channel_cents: { online: orders.sum(:total_cents), pos: pos.sum(:total_cents) },
        discounts_cents: orders.sum("discount_cents + loyalty_discount_cents + delivery_discount_cents") +
          pos.sum("automatic_discount_cents + manual_discount_cents + loyalty_discount_cents"),
        categories: order_items.group(:category_name).sum(:line_total_cents),
        brands: order_items.group(:brand_name).sum(:line_total_cents),
        products: merge_sums(order_items.group(:product_name).sum(:line_total_cents), pos_items.group(:product_name).sum(:line_total_cents)),
        payment_methods: PosPayment.joins(:pos_sale).merge(pos).group(:payment_method).sum(:amount_cents)
      }
    end

    def purchasing
      orders = branch_scope(PurchaseOrder.where(created_at: period))
      receipts = branch_scope(PurchaseReceipt.where(received_at: period))
      receipt_items = PurchaseReceiptItem.joins(purchase_receipt: :purchase_order).merge(receipts)
      lead_rows = receipts.joins(:purchase_order).where.not(purchase_orders: { ordered_at: nil })
      {
        spend_cents: receipt_items.sum("purchase_receipt_items.quantity * purchase_receipt_items.unit_cost_cents"),
        received_units: receipt_items.sum(:quantity), overdue_orders: branch_scope(PurchaseOrder.overdue).count,
        partial_receipt_rate: ratio(orders.partially_received.count, orders.count),
        spend_by_supplier: receipt_items.group("purchase_orders.supplier_id").sum("purchase_receipt_items.quantity * purchase_receipt_items.unit_cost_cents"),
        cost_trend: receipt_items.group("DATE(purchase_receipts.received_at)").sum("purchase_receipt_items.quantity * purchase_receipt_items.unit_cost_cents"),
        observed_lead_time_days: lead_rows.average("EXTRACT(EPOCH FROM (purchase_receipts.received_at - purchase_orders.ordered_at)) / 86400")&.round(2),
        unit_cost_range_cents: { minimum: receipt_items.minimum(:unit_cost_cents), maximum: receipt_items.maximum(:unit_cost_cents) }
      }
    end

    def inventory
      batches = branch_scope(InventoryBatch.all)
      movements = branch_scope(InventoryMovement.where(created_at: period))
      {
        physical_units: batches.sum(:on_hand_quantity), available_units: batches.sum("on_hand_quantity-reserved_quantity-returned_quarantine_quantity"),
        reserved_units: batches.sum(:reserved_quantity), quarantined_units: batches.sum(:returned_quarantine_quantity),
        valuation_cents: batches.sum("on_hand_quantity * unit_cost_cents"), expired_units: batches.expired.sum(:on_hand_quantity),
        near_expiry_units: batches.near_expiry(days: 90).sum(:on_hand_quantity),
        ageing: { under_30_days: batches.where(received_at: 30.days.ago..).sum(:on_hand_quantity),
          days_30_to_90: batches.where(received_at: 90.days.ago...30.days.ago).sum(:on_hand_quantity),
          over_90_days: batches.where(received_at: ...90.days.ago).sum(:on_hand_quantity) },
        movement_units: movements.group(:movement_type).sum(:quantity_delta),
        transfer_out_units: movements.branch_transfer_out.sum("ABS(quantity_delta)"), transfer_in_units: movements.branch_transfer_in.sum(:quantity_delta),
        by_branch: batches.group(:branch_id).sum(:on_hand_quantity)
      }
    end

    def customers
      orders = branch_scope(Order.where(created_at: period)).where.not(status: %i[cancelled rejected])
      pos = branch_scope(PosSale.completed.where(completed_at: period)).where.not(customer_id: nil)
      counts = orders.group(:user_id).count.merge(pos.group(:customer_id).count) { |_id, left, right| left + right }
      identified = counts.size
      total = orders.sum(:total_cents) + pos.sum(:total_cents)
      {
        identified_customers: identified, repeat_customers: counts.count { |_id, count| count > 1 },
        average_purchase_frequency: identified.zero? ? 0 : (counts.values.sum.to_f / identified).round(2),
        average_customer_transaction_cents: counts.values.sum.zero? ? 0 : (total.to_f / counts.values.sum).round,
        loyalty_participants: LoyaltyAccount.where(user_id: counts.keys).count,
        wallet_users: WalletLedgerEntry.where(occurred_at: period).distinct.count(:wallet_account_id)
      }
    end

    def prescriptions
      reviews = review_scope.where(created_at: period)
      items = PrescriptionReviewItem.joins(:prescription_review).merge(reviews)
      completed = reviews.where.not(completed_at: nil)
      {
        pending: reviews.pending.count, decisions: items.group(:status).count,
        substitution_rate: ratio(items.substituted.count, items.where(status: %i[approved rejected substituted]).count),
        average_turnaround_seconds: completed.average("EXTRACT(EPOCH FROM (completed_at - created_at))")&.round,
        pharmacist_workload: items.where.not(reviewed_by_id: nil).group(:reviewed_by_id).count
      }
    end

    def safety
      findings = DrugSafetyFinding.joins(drug_safety_evaluation: :prescription_review).merge(review_scope).where(created_at: period)
      {
        count: findings.count, severity: findings.group(:severity).count, statuses: findings.group(:status).count,
        blocking: findings.where(blocking: true).count,
        rule_types: findings.joins(:drug_safety_rule).group("drug_safety_rules.rule_type").count,
        acknowledgements: DrugSafetyAcknowledgement.where(created_at: period).count,
        after_substitution: findings.joins(:prescription_review_item).merge(PrescriptionReviewItem.substituted).count
      }
    end

    def search
      return restricted_section if @branch_ids.any?
      events = SearchEvent.where(created_at: period)
      {
        searches: events.count, zero_results: events.zero_result.count, contexts: events.group(:context).count,
        common_queries: events.group(:normalized_query).order(Arel.sql("COUNT(*) DESC")).limit(20).count,
        selected_products: events.where.not(selected_product_id: nil).group(:selected_product_id).count
      }
    end

    def loyalty
      entries = branch_scope(LoyaltyLedgerEntry.where(occurred_at: period))
      { by_type: entries.group(:entry_type).sum(:points), outstanding_points: LoyaltyLedgerEntry.sum(LoyaltyLedgerEntry.balance_sql),
        by_branch: entries.group(:branch_id).sum(:points), by_channel: entries.group("metadata->>'channel'").sum(:points) }
    end

    def wallet
      entries = branch_scope(WalletLedgerEntry.where(occurred_at: period))
      { by_type_cents: entries.group(:entry_type).sum(:amount_cents), liability_cents: WalletLedgerEntry.sum(WalletLedgerEntry.balance_sql),
        by_branch_cents: entries.group(:branch_id).sum(:amount_cents),
        by_channel_cents: entries.group("metadata->>'channel'").sum(:amount_cents) }
    end

    def returns
      records = branch_scope(ReturnRequest.where(created_at: period))
      items = ReturnItem.joins(:return_request).merge(records)
      refunds = Refund.joins(:return_request).merge(records).completed
      source_counts = records.group(:source_type).count
      transactions = branch_scope(Order.where(created_at: period)).count + branch_scope(PosSale.where(created_at: period)).count
      { count: records.count, rate: ratio(records.count, transactions), reasons: items.group(:reason).count,
        dispositions: items.group(:disposition).sum(:received_quantity), refunds_cents: refunds.sum(:amount_cents),
        channels: { online: source_counts.fetch("Order", 0), pos: source_counts.fetch("PosSale", 0) },
        by_branch: records.group(:branch_id).count }
    end

    def branches
      Branch.active.where(id: allowed_branch_ids).order(:code).map do |branch|
        { id: branch.id, code: branch.code, sales_cents: Order.where(branch:, created_at: period).sum(:total_cents) + PosSale.completed.where(branch:, completed_at: period).sum(:total_cents),
          inventory_units: InventoryBatch.where(branch:).sum(:on_hand_quantity), purchasing_cents: PurchaseOrder.where(branch:, created_at: period).sum(:total_cents),
          returns: ReturnRequest.where(branch:, created_at: period).count, pos_count: PosSale.completed.where(branch:, completed_at: period).count,
          fulfilments: Fulfilment.where(branch:, created_at: period).count,
          transfers_out: StockTransfer.where(source_branch: branch, created_at: period).count,
          transfers_in: StockTransfer.where(destination_branch: branch, created_at: period).count }
      end
    end

    def comparison
      previous = self.class.new(range: @range.previous, branches: @branches).send(:sales)
      current = sales
      %i[gross_cents net_cents online_count pos_count].to_h do |metric|
        old = previous.fetch(metric)
        [ metric, { current: current.fetch(metric), previous: old, percentage_change: old.zero? ? nil : (((current.fetch(metric) - old) * 100.0) / old).round(2) } ]
      end
    end

    def period = @range.from..@range.to
    def review_scope
      return PrescriptionReview.all unless @branch_ids.any?
      order_ids = Order.where(branch_id: @branch_ids).select(:id)
      pos_ids = PosSale.where(branch_id: @branch_ids).select(:id)
      PrescriptionReview.where(reviewable_type: "Order", reviewable_id: order_ids)
        .or(PrescriptionReview.where(reviewable_type: "PosSale", reviewable_id: pos_ids))
    end

    def restricted_section = { restricted: true }
    def allowed_branch_ids = @branch_ids.any? ? @branch_ids : Branch.active.ids
    def branch_scope(relation) = @branch_ids.any? && relation.klass.column_names.include?("branch_id") ? relation.where(branch_id: @branch_ids) : relation
    def ratio(numerator, denominator) = denominator.zero? ? 0.0 : (numerator.to_f / denominator).round(4)
    def merge_sums(left, right) = left.merge(right) { |_key, a, b| a + b }
  end
end
