class OrderFollowUp < ApplicationRecord
  belongs_to :order
  belongs_to :prescription, optional: true
  belongs_to :opened_by, class_name: "User"
  belongs_to :resolved_by, class_name: "User", optional: true
  has_many :messages, class_name: "OrderFollowUpMessage", dependent: :destroy
  has_many :notifications, as: :notifiable, dependent: :destroy

  enum :kind, { prescription_clarification: 0, replacement_requested: 1, quantity_confirmation: 2, unavailable_item: 3, delivery_question: 4, general: 5 }, validate: true
  enum :status, { open: 0, awaiting_customer: 1, customer_responded: 2, resolved: 3, cancelled: 4 }, default: :awaiting_customer, validate: true
  validates :subject, :customer_message, presence: true
  validates :response_required, inclusion: { in: [ true, false ] }
  validate :resolution_consistency

  scope :awaiting_response, -> { where(status: :awaiting_customer) }
  scope :overdue, -> { where(status: %i[open awaiting_customer customer_responded], due_at: ...Time.current) }

  def customer_messages = messages.where(customer_visible: true)

  private

  def resolution_consistency
    return unless resolved?

    errors.add(:resolved_by, "مطلوب") unless resolved_by
    errors.add(:resolved_at, "مطلوب") unless resolved_at
  end
end
