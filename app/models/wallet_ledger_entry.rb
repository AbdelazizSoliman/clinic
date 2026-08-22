class WalletLedgerEntry < ApplicationRecord
  CREDIT_TYPES = %w[credit refund adjustment_credit reversal_credit].freeze
  belongs_to :wallet_account
  belongs_to :branch, default: -> { source.try(:branch) || Current.branch || Branch.default_branch }
  belongs_to :source, polymorphic: true, optional: true
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :reversal_of, class_name: "WalletLedgerEntry", optional: true
  enum :entry_type, { credit: 0, payment: 1, refund: 2, adjustment_credit: 3,
    adjustment_debit: 4, reversal_credit: 5 }, validate: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :reason, :occurred_at, :idempotency_key, presence: true
  validates :idempotency_key, uniqueness: true
  before_update { throw :abort }
  before_destroy { throw :abort }

  def self.balance_sql
    sanitize_sql_array([ "CASE WHEN entry_type IN (?) THEN amount_cents ELSE -amount_cents END", CREDIT_TYPES.map { |type| entry_types.fetch(type) } ])
  end
  def credit? = entry_type.in?(CREDIT_TYPES)
end
