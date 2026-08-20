class Refund < ApplicationRecord
  belongs_to :return_request
  belongs_to :source, polymorphic: true
  belongs_to :actor, class_name: "User"
  belongs_to :cashier_session, optional: true

  enum :payment_method, { cash: 0, external_card: 1, cash_on_delivery: 2 }, validate: true
  enum :status, { pending: 0, completed: 1, failed: 2, cancelled: 3 }, default: :pending, validate: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :idempotency_key, presence: true, uniqueness: true
  validates :external_reference, presence: true, if: -> { external_card? && completed? }
  validate { errors.add(:source, "لا يطابق المرتجع") unless source == return_request&.source }
  before_update :only_allow_terminal_confirmation
  before_destroy { throw :abort }

  private

  def only_allow_terminal_confirmation
    allowed = status_was == "pending" && (completed? || failed? || cancelled?)
    throw :abort unless allowed && (changes.keys - %w[status refunded_at external_reference notes updated_at]).empty?
  end
end
