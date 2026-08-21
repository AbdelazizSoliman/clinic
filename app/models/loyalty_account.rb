class LoyaltyAccount < ApplicationRecord
  belongs_to :user
  has_many :ledger_entries, class_name: "LoyaltyLedgerEntry", dependent: :restrict_with_error
  enum :status, { active: 0, suspended: 1 }, default: :active, validate: true
  validates :user_id, uniqueness: true
  validate { errors.add(:user, "يجب أن يكون عميلاً") unless user&.customer? }

  def points_balance = ledger_entries.sum(Arel.sql(LoyaltyLedgerEntry.balance_sql))
  def lifetime_earned_points = ledger_entries.earn.sum(:points)
end
