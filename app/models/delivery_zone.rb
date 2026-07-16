class DeliveryZone < ApplicationRecord
  has_many :districts, class_name: "DeliveryZoneDistrict", dependent: :destroy
  has_many :delivery_methods, dependent: :destroy
  has_many :delivery_slots, dependent: :restrict_with_error
  has_many :orders, dependent: :restrict_with_error

  validates :name, :code, :governorate, :city, presence: true
  validates :code, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :name, uniqueness: { scope: %i[governorate city] }
  validates :delivery_fee_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :free_delivery_threshold_cents, :minimum_order_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :estimated_min_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :estimated_max_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate { errors.add(:estimated_max_minutes, "يجب ألا يقل عن الحد الأدنى") if estimated_min_minutes && estimated_max_minutes && estimated_max_minutes < estimated_min_minutes }
  scope :active, -> { where(active: true) }

  def fee_for(subtotal_cents, method: nil)
    base = free_delivery_threshold_cents && subtotal_cents >= free_delivery_threshold_cents ? 0 : delivery_fee_cents
    base + method.to_i
  end
end
