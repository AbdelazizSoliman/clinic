module StockTransfers
  class Workflow
    Result = Data.define(:success?, :transfer, :errors)

    def initialize(transfer:, actor:, action:)
      @transfer, @actor, @action = transfer, actor, action.to_s
    end

    def call
      return failure("غير مصرح بتحويل المخزون") unless @actor&.can_transfer_stock?
      unless Operations::TenantGuard.same_organization?(@actor, @transfer, @transfer.source_branch, @transfer.destination_branch)
        return failure("لا يمكن التحويل بين مؤسسات مختلفة")
      end
      unless @actor.admin? || (@actor.branch_access?(@transfer.source_branch) && @actor.branch_access?(@transfer.destination_branch))
        return failure("لا يملك المستخدم صلاحية الوصول إلى فرعي التحويل")
      end
      StockTransfer.transaction do
        @transfer.lock!
        return success if already_applied?
        send("#{@action}!")
      end
      success
    rescue ActiveRecord::RecordInvalid => error
      failure(error.record.errors.full_messages.join("، "))
    end

    private

    def submit!
      raise ActiveRecord::RecordInvalid, @transfer unless @transfer.draft? && @transfer.items.exists?
      @transfer.update!(status: :submitted, submitted_by: @actor, submitted_at: Time.current)
      audit("stock_transfer_submitted")
    end

    def dispatch!
      raise ActiveRecord::RecordInvalid, @transfer unless @transfer.submitted?
      @transfer.items.includes(:product).order(:product_id).lock.each do |item|
        remaining = item.requested_quantity
        InventoryBatch.where(branch: @transfer.source_branch, product: item.product).allocatable.fefo.lock.each do |batch|
          quantity = [ remaining, batch.available_quantity ].min
          next unless quantity.positive?
          product = item.product.reload
          product_before = product.stock_quantity
          batch_before = batch.on_hand_quantity
          batch.update!(on_hand_quantity: batch_before - quantity)
          Inventory::BatchAggregate.sync_product!(product)
          movement = product.inventory_movements.create!(branch: @transfer.source_branch, actor: @actor,
            inventory_batch: batch, reference: @transfer, movement_type: :branch_transfer_out,
            quantity_delta: -quantity, quantity_before: product_before, quantity_after: product.stock_quantity,
            batch_quantity_before: batch_before, batch_quantity_after: batch.on_hand_quantity,
            reason: "إرسال تحويل #{@transfer.number}",
            idempotency_key: "transfer-out:#{@transfer.id}:item:#{item.id}:batch:#{batch.id}")
          item.batch_allocations.create!(source_inventory_batch: batch, out_movement: movement, quantity:)
          remaining -= quantity
          break if remaining.zero?
        end
        if remaining.positive?
          item.errors.add(:requested_quantity, "تتجاوز مخزون فرع المصدر")
          raise ActiveRecord::RecordInvalid, item
        end
        item.update!(dispatched_quantity: item.requested_quantity)
      end
      @transfer.update!(status: :dispatched, dispatched_by: @actor, dispatched_at: Time.current)
      audit("stock_transfer_dispatched")
    end

    def receive!
      raise ActiveRecord::RecordInvalid, @transfer unless @transfer.dispatched?
      @transfer.items.includes(batch_allocations: :source_inventory_batch).order(:id).lock.each do |item|
        item.batch_allocations.order(:id).lock.each do |allocation|
          source = allocation.source_inventory_batch
          product = item.product.reload
          product_before = product.stock_quantity
          batch = InventoryBatch.create!(branch: @transfer.destination_branch, product:, supplier: source.supplier,
            source_inventory_batch: source, batch_number: "#{source.batch_number}-T#{@transfer.id}",
            lot_number: source.lot_number || source.batch_number, manufacture_date: source.manufacture_date,
            expiry_date: source.expiry_date, received_at: Time.current, original_quantity: allocation.quantity,
            on_hand_quantity: allocation.quantity, reserved_quantity: 0, unit_cost_cents: source.unit_cost_cents,
            notes: "وارد تحويل #{@transfer.number}")
          Inventory::BatchAggregate.sync_product!(product)
          movement = product.inventory_movements.create!(branch: @transfer.destination_branch, actor: @actor,
            inventory_batch: batch, reference: @transfer, movement_type: :branch_transfer_in,
            quantity_delta: allocation.quantity, quantity_before: product_before, quantity_after: product.stock_quantity,
            batch_quantity_before: 0, batch_quantity_after: allocation.quantity,
            reason: "استلام تحويل #{@transfer.number}",
            idempotency_key: "transfer-in:#{@transfer.id}:allocation:#{allocation.id}")
          allocation.update!(destination_inventory_batch: batch, in_movement: movement)
        end
        item.update!(received_quantity: item.dispatched_quantity)
      end
      @transfer.update!(status: :received, received_by: @actor, received_at: Time.current)
      audit("stock_transfer_received")
    end

    def close!
      raise ActiveRecord::RecordInvalid, @transfer unless @transfer.received?
      @transfer.update!(status: :closed, closed_at: Time.current)
      audit("stock_transfer_closed")
    end

    def cancel!
      unless @transfer.draft? || @transfer.submitted?
        @transfer.errors.add(:base, "لا يمكن إلغاء التحويل بعد الإرسال الفعلي")
        raise ActiveRecord::RecordInvalid, @transfer
      end
      reason = @transfer.cancellation_reason.presence || "إلغاء تشغيلي موثق"
      @transfer.update!(status: :cancelled, cancelled_by: @actor, cancelled_at: Time.current, cancellation_reason: reason)
      audit("stock_transfer_cancelled")
    end

    def already_applied?
      { "submit" => !@transfer.draft?, "dispatch" => @transfer.dispatched? || @transfer.received? || @transfer.closed?,
        "receive" => @transfer.received? || @transfer.closed?, "close" => @transfer.closed?,
        "cancel" => @transfer.cancelled? }.fetch(@action, false)
    end

    def audit(action)
      AdminAuditEvent.create!(actor: @actor, auditable: @transfer, action:,
        metadata: { number: @transfer.number, source_branch: @transfer.source_branch.code,
                    destination_branch: @transfer.destination_branch.code })
    end

    def success = Result.new(success?: true, transfer: @transfer, errors: [])
    def failure(message) = Result.new(success?: false, transfer: @transfer, errors: [ message ])
  end
end
