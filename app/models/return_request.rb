class ReturnRequest < ApplicationRecord
  belongs_to :source, polymorphic: true
  belongs_to :requested_by, class_name: "User"
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_many :items, class_name: "ReturnItem", dependent: :restrict_with_error, inverse_of: :return_request
  has_many :refunds, dependent: :restrict_with_error
  has_many :audit_events, as: :auditable, class_name: "AdminAuditEvent", dependent: :restrict_with_error

  enum :status, { draft: 0, submitted: 1, under_review: 2, approved: 3, received: 4,
    refunded: 5, closed: 6, rejected: 7, cancelled: 8 }, default: :draft, validate: true

  validates :number, presence: true, uniqueness: true
  validates :source_type, inclusion: { in: %w[Order PosSale] }

  def refundable_cents = items.sum(:refundable_amount_cents)
  def refunded_cents = refunds.completed.sum(:amount_cents)
  def remaining_refundable_cents = refundable_cents - refunded_cents
  def medication_inspection_pending? = items.where(pharmacist_inspection_required: true, inspected_at: nil).exists?
  def to_param = number
end
