class PrescriptionReviewItem < ApplicationRecord
  belongs_to :prescription_review
  belongs_to :reviewable_item, polymorphic: true
  belongs_to :original_product, class_name: "Product"
  belongs_to :dispensed_product, class_name: "Product", optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_one :therapeutic_substitution, dependent: :restrict_with_error
  has_many :decisions, class_name: "PrescriptionDecision", dependent: :restrict_with_error
  # Findings are immutable clinical evidence. The only cascade is a draft POS line removed
  # before anything was dispensed, where the review item itself disappears with the line.
  has_many :safety_findings, class_name: "DrugSafetyFinding", dependent: :destroy
  has_many :related_safety_findings, class_name: "DrugSafetyFinding",
    foreign_key: :related_review_item_id, dependent: :nullify, inverse_of: :related_review_item

  enum :status, { pending: 0, under_review: 1, approved: 2, substituted: 3, rejected: 4 },
    default: :pending, validate: true

  validates :reviewable_item_id, uniqueness: {
    scope: %i[prescription_review_id reviewable_item_type]
  }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :prescribed_unit_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :dispensed_unit_price_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :reason, presence: true, if: -> { approved? || substituted? || rejected? }
  validate :source_matches_review
  validate :decision_is_consistent
  validate :terminal_decision_is_immutable, on: :update

  def terminal? = approved? || substituted? || rejected?
  def dispensable? = approved? || substituted?
  def effective_product = dispensed_product
  # The product the safety engine reasons about right now: the dispensed one once decided,
  # otherwise the prescribed one.
  def candidate_product = dispensed_product || original_product
  def effective_unit_price_cents = dispensed_unit_price_cents
  def line_adjustment_cents
    dispensed_total = dispensable? ? dispensed_unit_price_cents * quantity : 0
    dispensed_total - prescribed_unit_price_cents * quantity
  end

  private

  def source_matches_review
    expected = prescription_review&.online? ? "OrderItem" : "PosSaleItem"
    errors.add(:reviewable_item_type, "لا يطابق مصدر المراجعة") if expected && reviewable_item_type != expected
    return unless reviewable_item
    errors.add(:original_product, "لا يطابق البند الموصوف") unless reviewable_item.product_id == original_product_id
  end

  def decision_is_consistent
    if approved?
      errors.add(:dispensed_product, "يجب أن يطابق المنتج الموصوف") unless dispensed_product_id == original_product_id
    elsif substituted?
      errors.add(:dispensed_product, "يجب أن يختلف عن المنتج الموصوف") if dispensed_product_id.blank? || dispensed_product_id == original_product_id
    elsif rejected?
      errors.add(:dispensed_product, "غير مسموح مع الرفض") if dispensed_product_id
    end
    if terminal?
      errors.add(:reviewed_by, "مطلوب") unless reviewed_by&.pharmacist?
      errors.add(:reviewed_at, "مطلوب") unless reviewed_at
    elsif reviewed_by_id || reviewed_at
      errors.add(:base, "لا يسجل مراجع قبل القرار النهائي")
    end
  end

  def terminal_decision_is_immutable
    return unless status_was.in?(%w[approved substituted rejected])
    errors.add(:base, "قرار البند السريري غير قابل للتعديل") if changes.except("updated_at").any?
  end
end
