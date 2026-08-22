class PurchaseOrder < ApplicationRecord
  belongs_to :supplier
  belongs_to :branch, default: -> { Current.branch || created_by&.default_branch || Branch.default_branch }
  belongs_to :created_by, class_name: "User"
  belongs_to :approved_by, class_name: "User", optional: true
  belongs_to :cancelled_by, class_name: "User", optional: true
  has_many :items, class_name: "PurchaseOrderItem", dependent: :restrict_with_error
  has_many :receipts, class_name: "PurchaseReceipt", dependent: :restrict_with_error
  has_many :events, class_name: "PurchaseOrderEvent", dependent: :restrict_with_error

  enum :status, { draft: 0, submitted: 1, approved: 2, partially_received: 3, received: 4, closed: 5, cancelled: 6 }, default: :draft, validate: true

  validates :number, presence: true, uniqueness: true
  validates :currency, inclusion: { in: %w[EGP] }
  validates :subtotal_cents, :discount_total_cents, :tax_total_cents, :total_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :totals_reconcile
  validate :cancellation_has_reason

  scope :outstanding, -> { where(status: %i[approved partially_received]) }
  scope :overdue, -> { outstanding.where("expected_at < ?", Date.current) }

  def editable? = draft?
  def receivable? = approved? || partially_received?
  def to_param = number
  def outstanding_quantity = items.sum { |item| item.ordered_quantity - item.received_quantity }
  def recalculate_totals!
    subtotal = items.sum(:line_total_cents)
    update!(subtotal_cents: subtotal, total_cents: subtotal - discount_total_cents + tax_total_cents)
  end

  private

  def totals_reconcile
    errors.add(:total_cents, "لا يطابق مكونات الإجمالي") unless total_cents == subtotal_cents - discount_total_cents + tax_total_cents
  end

  def cancellation_has_reason
    errors.add(:cancellation_reason, "مطلوب") if cancelled? && cancellation_reason.blank?
  end
end
