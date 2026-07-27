class PosSaleBatchAllocation < ApplicationRecord
  belongs_to :pos_sale_item
  belongs_to :inventory_batch
  belongs_to :inventory_movement, optional: true

  validates :inventory_batch_id, uniqueness: { scope: :pos_sale_item_id }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_cost_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate { errors.add(:inventory_batch, "لا يطابق المنتج") if inventory_batch && inventory_batch.product_id != pos_sale_item&.product_id }
  before_update { throw :abort }
  before_destroy { throw :abort }
end
