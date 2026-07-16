class DeliveryMethod < ApplicationRecord
  CODES = %w[standard scheduled pharmacy_pickup].freeze
  belongs_to :delivery_zone
  validates :code, inclusion: { in: CODES }, uniqueness: { scope: :delivery_zone_id }
  validates :name, presence: true
  validates :additional_fee_cents, :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  def scheduled? = code == "scheduled"
end
