class DeliverySlot < ApplicationRecord
  belongs_to :delivery_zone
  has_many :orders, dependent: :restrict_with_error
  has_many :fulfilments, dependent: :restrict_with_error
  validates :delivery_date, :starts_at, :ends_at, presence: true
  validates :capacity, numericality: { only_integer: true, greater_than: 0 }
  validates :booked_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate { errors.add(:ends_at, "يجب أن يكون بعد وقت البداية") if starts_at && ends_at && ends_at <= starts_at }
  validate { errors.add(:booked_count, "يتجاوز السعة") if capacity && booked_count && booked_count > capacity }
  scope :available, -> { where(active: true).where("delivery_date >= ? AND booked_count < capacity", Date.current) }
  def available? = active? && delivery_date >= Date.current && booked_count < capacity
  def remaining_capacity = [ capacity - booked_count, 0 ].max
  def scheduled_at = Time.zone.local(delivery_date.year, delivery_date.month, delivery_date.day, starts_at.hour, starts_at.min)
end
