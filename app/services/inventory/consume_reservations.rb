module Inventory
  class ConsumeReservations
    def initialize(order)
      @order = order
    end

    def call
      InventoryReservation.transaction do
        reservations = @order.inventory_reservations.active.includes(:product, reservation_allocations: :inventory_batch).order(:product_id).lock
        return false if reservations.empty?

        Product.where(id: reservations.map(&:product_id)).order(:id).lock.load
        reservations.each do |reservation|
          product = reservation.product.reload
          allocations = reservation.reservation_allocations.sort_by(&:inventory_batch_id)
          raise ActiveRecord::Rollback unless allocations.sum(&:quantity) == reservation.quantity
          allocations.each do |allocation|
            batch = allocation.inventory_batch
            batch.lock!
            if batch.reserved_quantity < allocation.quantity
              missing = allocation.quantity - batch.reserved_quantity
              raise ActiveRecord::Rollback if batch.available_quantity < missing || batch.expired? || batch.quarantined?
              batch.update!(reserved_quantity: batch.reserved_quantity + missing)
            end
            raise ActiveRecord::Rollback if batch.reserved_quantity < allocation.quantity || batch.on_hand_quantity < allocation.quantity
            product_before = product.stock_quantity
            batch_before = batch.on_hand_quantity
            batch.update!(on_hand_quantity: batch_before - allocation.quantity,
              reserved_quantity: batch.reserved_quantity - allocation.quantity)
            Inventory::BatchAggregate.sync_product!(product)
            product.inventory_movements.create!(inventory_batch: batch, movement_type: :reservation_consumed,
              quantity_delta: -allocation.quantity, quantity_before: product_before, quantity_after: product.stock_quantity,
              batch_quantity_before: batch_before, batch_quantity_after: batch.on_hand_quantity,
              reason: "استهلاك حجز الطلب #{reservation.order.number}", reference: allocation,
              idempotency_key: "reservation-allocation-consumed-#{allocation.id}")
          end
          reservation.update!(status: :consumed, consumed_at: Time.current)
        end
      end
      @order.inventory_reservations.active.none?
    end
  end
end
