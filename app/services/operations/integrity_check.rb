module Operations
  class IntegrityCheck
    Finding = Data.define(:code, :severity, :count, :identifiers)
    LIMIT = 20

    def call
      checks.filter_map { |code, severity, relation| finding(code, severity, relation) }
    end

    private

    def checks
      terminal = Order.statuses.values_at("delivered", "cancelled", "rejected")
      [
        [ :completed_carts_without_orders, :high, Cart.completed.left_joins(:order).where(orders: { id: nil }) ],
        [ :orders_without_completed_carts, :high, Order.joins(:cart).where.not(carts: { status: Cart.statuses[:completed] }) ],
        [ :orders_without_items, :critical, Order.left_joins(:items).where(order_items: { id: nil }) ],
        [ :orders_without_address_snapshot, :high, Order.left_joins(:order_address).where(order_addresses: { id: nil }) ],
        [ :orders_with_invalid_totals, :critical, Order.where("total_cents <> subtotal_cents - discount_cents + delivery_fee_cents - delivery_discount_cents") ],
        [ :terminal_orders_with_active_reservations, :high, InventoryReservation.active.joins(:order).where(orders: { status: terminal }) ],
        [ :delivered_orders_with_unconsumed_reservations, :high, InventoryReservation.where.not(status: InventoryReservation.statuses[:consumed]).joins(:order).where(orders: { status: Order.statuses[:delivered] }) ],
        [ :consumed_reservations_without_movements, :high, InventoryReservation.consumed.where.not(id: InventoryMovement.reservation_consumed.where(reference_type: "InventoryReservation").select(:reference_id)) ],
        [ :prescriptions_not_clean, :critical, Prescription.where.not(scan_status: Prescription.scan_statuses[:clean]) ],
        [ :product_images_without_blobs, :medium, ProductImage.left_joins(file_attachment: :blob).where(active_storage_blobs: { id: nil }) ],
        [ :completed_exports_without_files, :medium, ReportExport.completed.left_joins(file_attachment: :blob).where(active_storage_blobs: { id: nil }) ],
        [ :duplicate_pharmacy_settings, :high, PharmacySetting.where.not(id: PharmacySetting.order(:id).limit(1)) ],
        [ :stale_job_heartbeats, :high, JobHeartbeat.where(last_succeeded_at: ...15.minutes.ago) ],
        [ :failed_malware_scans, :critical, Prescription.scan_failed ],
        [ :privileged_without_two_factor, :critical, User.where.not(role: User.roles[:customer]).where(active: true, otp_enabled_at: nil) ]
      ]
    end

    def finding(code, severity, relation)
      count = relation.limit(LIMIT + 1).count
      return if count.zero?
      ids = relation.limit(LIMIT).pluck(:id).map(&:to_s)
      Finding.new(code:, severity:, count:, identifiers: ids)
    end
  end
end
