module Inventory
  class ConsumeReservations
    def initialize(order)
      @order = order
    end

    def call
      InventoryReservation.transaction do
        reservations = @order.inventory_reservations.active.includes(:product).order(:product_id).lock
        return false if reservations.empty?

        Product.where(id: reservations.map(&:product_id)).order(:id).lock.load
        reservations.each do |reservation|
          product = reservation.product.reload
          raise ActiveRecord::Rollback if product.stock_quantity < reservation.quantity

          product.update!(stock_quantity: product.stock_quantity - reservation.quantity)
          reservation.update!(status: :consumed, consumed_at: Time.current)
        end
      end
      @order.inventory_reservations.active.none?
    end
  end
end
