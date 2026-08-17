module Inventory
  class ReleaseReservation
    def self.call(reservation)
      InventoryReservation.transaction do
        reservation.lock!
        return true unless reservation.active?
        reservation.reservation_allocations.includes(:inventory_batch).order(:inventory_batch_id).each do |allocation|
          batch = allocation.inventory_batch
          batch.lock!
          batch.update!(reserved_quantity: batch.reserved_quantity - allocation.quantity)
        end
        reservation.update!(status: :released, released_at: Time.current)
      end
      true
    end
  end
end
