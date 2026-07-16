class InventoryMovement < ApplicationRecord
  belongs_to :product
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :reference, polymorphic: true, optional: true
  enum :movement_type, { opening_balance: 0, manual_increase: 1, manual_decrease: 2, correction: 3, reservation_consumed: 4, return_to_stock: 5, damaged: 6, expired: 7, system_adjustment: 8 }, validate: true
  validates :quantity_delta, numericality: { only_integer: true, other_than: 0 }
  validates :quantity_before, :quantity_after, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :reason, presence: true
  validates :idempotency_key, uniqueness: true, allow_nil: true
  validate { errors.add(:quantity_after, "لا يطابق الحركة") unless quantity_after == quantity_before + quantity_delta }
  before_update { throw :abort }
  before_destroy { throw :abort }
end
