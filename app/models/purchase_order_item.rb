class PurchaseOrderItem < ApplicationRecord
  belongs_to :purchase_order
  belongs_to :product
  has_many :receipt_items, class_name: "PurchaseReceiptItem", dependent: :restrict_with_error

  validates :product_name_snapshot, presence: true
  validates :ordered_quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :received_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :unit_cost_cents, :discount_cents, :tax_cents, :line_total_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :product_id, uniqueness: { scope: :purchase_order_id }
  validate :received_not_above_ordered
  validate :line_total_reconciles
  validate :commercial_fields_change_only_in_draft, on: :update

  def outstanding_quantity = ordered_quantity - received_quantity

  private

  def received_not_above_ordered
    errors.add(:received_quantity, "لا يمكن أن تتجاوز الكمية المطلوبة") if received_quantity.to_i > ordered_quantity.to_i
  end

  def line_total_reconciles
    expected = unit_cost_cents.to_i * ordered_quantity.to_i - discount_cents.to_i + tax_cents.to_i
    errors.add(:line_total_cents, "غير صحيح") unless line_total_cents == expected
  end

  def commercial_fields_change_only_in_draft
    return if purchase_order.draft?
    frozen = %w[product_id product_name_snapshot sku_snapshot ordered_quantity unit_cost_cents discount_cents tax_cents line_total_cents]
    errors.add(:base, "بنود أمر الشراء مجمدة بعد الإرسال") if (changes.keys & frozen).any?
  end
end
