class InventoryBatch < ApplicationRecord
  belongs_to :product
  belongs_to :supplier, optional: true
  belongs_to :purchase_receipt, optional: true
  belongs_to :purchase_receipt_item, optional: true
  belongs_to :quarantined_by, class_name: "User", optional: true
  has_many :inventory_movements, dependent: :restrict_with_error
  has_many :reservation_allocations, class_name: "InventoryReservationAllocation", dependent: :restrict_with_error
  has_many :events, class_name: "InventoryBatchEvent", dependent: :restrict_with_error
  has_many :inventory_reservations, through: :reservation_allocations

  normalizes :batch_number, :lot_number, with: ->(value) { value.to_s.strip.upcase.presence }

  validates :batch_number, :expiry_date, :received_at, presence: true
  validates :batch_number, uniqueness: true, length: { maximum: 100 }
  validates :original_quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :on_hand_quantity, :reserved_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :unit_cost_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :quarantine_reason, presence: true, if: :quarantined?
  validate :quantity_consistency
  validate :expiry_after_manufacture
  validate :commercial_links_consistent
  validate :identity_is_immutable, on: :update

  scope :fefo, -> { order(:expiry_date, :received_at, :id) }
  scope :not_quarantined, -> { where(quarantined_at: nil) }
  scope :unexpired, ->(on = Date.current) { where("expiry_date >= ?", on) }
  scope :allocatable, ->(on = Date.current) { not_quarantined.unexpired(on).where("on_hand_quantity > reserved_quantity") }
  scope :expired, ->(on = Date.current) { where(expiry_date: ...on) }
  scope :near_expiry, ->(days:, on: Date.current) { unexpired(on).where(expiry_date: on..(on + days.days)) }

  def available_quantity = on_hand_quantity - reserved_quantity
  def consumed_quantity = [ original_quantity - on_hand_quantity, 0 ].max
  def quarantined? = quarantined_at.present?
  def expired?(on = Date.current) = expiry_date < on

  def lifecycle_status(on = Date.current)
    return "quarantined" if quarantined?
    return "expired" if expired?(on)
    return "consumed" if on_hand_quantity.zero?
    return "reserved" if reserved_quantity == on_hand_quantity
    return "partially_consumed" if consumed_quantity.positive?
    "available"
  end

  private

  def quantity_consistency
    errors.add(:reserved_quantity, "لا يمكن أن تتجاوز الرصيد الفعلي") if reserved_quantity.to_i > on_hand_quantity.to_i
  end

  def expiry_after_manufacture
    errors.add(:expiry_date, "يجب أن يلي تاريخ الإنتاج") if manufacture_date && expiry_date && expiry_date <= manufacture_date
  end

  def commercial_links_consistent
    return unless purchase_receipt_item
    errors.add(:purchase_receipt, "لا يطابق بند الاستلام") unless purchase_receipt_item.purchase_receipt_id == purchase_receipt_id
    errors.add(:product, "لا يطابق بند الاستلام") unless purchase_receipt_item.purchase_order_item.product_id == product_id
  end

  def identity_is_immutable
    fields = %w[product_id supplier_id purchase_receipt_id purchase_receipt_item_id batch_number lot_number manufacture_date expiry_date received_at original_quantity unit_cost_cents]
    errors.add(:base, "هوية التشغيلة وسجلها التجاري غير قابلين للتعديل") if (changes.keys & fields).any?
  end
end
