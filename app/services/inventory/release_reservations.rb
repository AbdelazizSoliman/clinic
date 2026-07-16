module Inventory
  class ReleaseReservations
    def initialize(order)
      @order = order
    end

    def call
      InventoryReservation.transaction do
        @order.inventory_reservations.lock.active.find_each do |reservation|
          reservation.update!(status: :released, released_at: Time.current)
        end
      end
      true
    end
  end
end
