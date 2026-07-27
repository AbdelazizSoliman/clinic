class PosSale < ApplicationRecord
  belongs_to :cashier_session
  belongs_to :cashier, class_name: "User"
  belongs_to :discount_approved_by, class_name: "User", optional: true
  belongs_to :voided_by, class_name: "User", optional: true
  has_many :items, class_name: "PosSaleItem", dependent: :restrict_with_error, inverse_of: :pos_sale
  has_many :payments, class_name: "PosPayment", dependent: :restrict_with_error

  enum :status, { draft: 0, completed: 1, voided: 2 }, default: :draft, validate: true

  validates :number, presence: true, uniqueness: true
  validates :currency, inclusion: { in: %w[EGP] }
  validates :subtotal_cents, :automatic_discount_cents, :manual_discount_cents, :tax_cents, :total_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :completion_idempotency_key, uniqueness: true, allow_nil: true
  validates :manual_discount_reason, presence: true, if: -> { manual_discount_cents.positive? }
  validate :total_is_consistent
  validate :approval_is_consistent
  validate :finalized_sale_is_immutable, on: :update

  def to_param = number
  def cash_payment = payments.find(&:cash?)
  def change_cents = payments.sum(:change_cents)

  private

  def total_is_consistent
    expected = subtotal_cents - automatic_discount_cents - manual_discount_cents + tax_cents
    errors.add(:total_cents, "لا يطابق مكونات الإجمالي") unless total_cents == expected
  end

  def approval_is_consistent
    return unless manual_discount_cents.positive?
    errors.add(:discount_approved_by, "مطلوب للخصم اليدوي") unless discount_approved_by
    errors.add(:discount_approved_at, "مطلوب للخصم اليدوي") unless discount_approved_at
  end

  def finalized_sale_is_immutable
    return if status_was == "draft"
    errors.add(:base, "عملية البيع النهائية غير قابلة للتعديل") if changes.except("updated_at").any?
  end
end
