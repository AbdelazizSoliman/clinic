class ReturnItemBatchAllocation < ApplicationRecord
  belongs_to :return_item
  belongs_to :original_allocation, polymorphic: true
  belongs_to :inventory_batch
  belongs_to :inventory_movement, optional: true
  enum :disposition, ReturnItem.dispositions, validate: true, prefix: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :idempotency_key, presence: true, uniqueness: true
  validate { errors.add(:inventory_batch, "لا يطابق التخصيص الأصلي") if original_allocation && original_allocation.inventory_batch_id != inventory_batch_id }
  before_update { throw :abort }
  before_destroy { throw :abort }
end
