class OrderPromotion < ApplicationRecord
  belongs_to :order
  belongs_to :promotion, optional: true
  belongs_to :coupon, optional: true
  validates :promotion_name, :promotion_type, :discount_type, presence: true
  validates :discount_cents, :discount_value_snapshot, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
