class InventoryReservation < ApplicationRecord
  belongs_to :order
  belongs_to :order_item
  belongs_to :product
  belongs_to :branch, default: -> { order&.branch || Current.branch || Branch.default_branch }
  has_many :reservation_allocations, class_name: "InventoryReservationAllocation", dependent: :restrict_with_error
  has_many :inventory_batches, through: :reservation_allocations

  enum :status, { active: 0, released: 1, consumed: 2 }, default: :active, validate: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :order_item_id, uniqueness: { scope: :status }

  scope :expired, -> { active.where(expires_at: ...Time.current) }
  scope :expiring_before, ->(time) { active.where(expires_at: ..time) }

  def expired? = active? && expires_at.present? && expires_at <= Time.current
  def allocated_quantity = reservation_allocations.sum(:quantity)
end
