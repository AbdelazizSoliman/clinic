class InventoryReservationAllocation < ApplicationRecord
  belongs_to :inventory_reservation
  belongs_to :inventory_batch

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :inventory_batch_id, uniqueness: { scope: :inventory_reservation_id }
  validate :product_matches_reservation
  before_update { throw :abort }
  before_destroy { throw :abort }

  delegate :order, :order_item, :product, to: :inventory_reservation

  private

  def product_matches_reservation
    return unless inventory_batch && inventory_reservation
    errors.add(:inventory_batch, "لا يطابق منتج الحجز") unless inventory_batch.product_id == inventory_reservation.product_id
  end
end
