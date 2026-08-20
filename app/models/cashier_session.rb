class CashierSession < ApplicationRecord
  belongs_to :user
  has_many :pos_sales, dependent: :restrict_with_error
  has_many :refunds, dependent: :restrict_with_error

  enum :status, { open: 0, closed: 1 }, default: :open, validate: true

  validates :identifier, :opened_at, presence: true
  validates :identifier, uniqueness: true
  validates :opening_cash_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :closing_cash_counted_cents, :expected_cash_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :closing_values_are_consistent
  validate :closed_session_is_immutable, on: :update

  def expected_cash
    opening_cash_cents + pos_sales.completed.joins(:payments)
      .merge(PosPayment.cash).sum(:amount_cents) - refunds.completed.cash.sum(:amount_cents)
  end

  private

  def closing_values_are_consistent
    return unless closed?
    errors.add(:closed_at, "مطلوب") unless closed_at
    errors.add(:expected_cash_cents, "مطلوب") if expected_cash_cents.nil?
    errors.add(:closing_cash_counted_cents, "مطلوب") if closing_cash_counted_cents.nil?
    return if expected_cash_cents.nil? || closing_cash_counted_cents.nil?
    errors.add(:cash_difference_cents, "لا يطابق التسوية") unless cash_difference_cents == closing_cash_counted_cents - expected_cash_cents
  end

  def closed_session_is_immutable
    return unless status_was == "closed"
    errors.add(:base, "جلسة الصندوق المغلقة غير قابلة للتعديل") if changes.except("updated_at").any?
  end
end
