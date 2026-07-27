module Inventory
  class ReleaseReservations
    def initialize(order)
      @order = order
    end

    def call
      InventoryReservation.transaction do
        @order.inventory_reservations.lock.active.order(:id).each do |reservation|
          reservation.reservation_allocations.includes(:inventory_batch).order(:inventory_batch_id).each do |allocation|
            batch = allocation.inventory_batch
            batch.lock!
            batch.update!(reserved_quantity: batch.reserved_quantity - allocation.quantity)
          end
          reservation.update!(status: :released, released_at: Time.current)
        end
      end
      true
    end
  end
end
