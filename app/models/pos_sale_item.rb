class PosSaleItem < ApplicationRecord
  belongs_to :pos_sale
  belongs_to :product
  belongs_to :prescription_approved_by, class_name: "User", optional: true
  has_many :batch_allocations, class_name: "PosSaleBatchAllocation", dependent: :restrict_with_error

  validates :product_id, uniqueness: { scope: :pos_sale_id }
  validates :product_name, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :original_unit_price_cents, :unit_price_cents, :discount_cents, :line_total_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :prescription_approval_is_consistent
  validate :finalized_item_is_immutable, on: :update

  def prescription_approved? = !requires_prescription? || prescription_approved_by_id.present?

  private

  def prescription_approval_is_consistent
    return unless prescription_approved_by_id || prescription_approved_at || prescription_approval_reason.present?
    errors.add(:prescription_approved_by, "غير مصرح") unless prescription_approved_by&.pharmacist?
    errors.add(:prescription_approved_at, "مطلوب") unless prescription_approved_at
    errors.add(:prescription_approval_reason, "مطلوب") if prescription_approval_reason.blank?
  end

  def finalized_item_is_immutable
    errors.add(:base, "بند البيع النهائي غير قابل للتعديل") unless pos_sale.draft?
  end
end
