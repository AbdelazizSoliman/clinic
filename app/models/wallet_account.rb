class WalletAccount < ApplicationRecord
  belongs_to :user
  has_many :ledger_entries, class_name: "WalletLedgerEntry", dependent: :restrict_with_error
  enum :status, { active: 0, suspended: 1 }, default: :active, validate: true
  validates :user_id, uniqueness: true
  validate { errors.add(:user, "يجب أن يكون عميلاً") unless user&.customer? }
  def balance_cents = ledger_entries.sum(Arel.sql(WalletLedgerEntry.balance_sql))
end
