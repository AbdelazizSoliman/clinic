class LoyaltyLedgerEntry < ApplicationRecord
  CREDIT_TYPES = %w[earn redemption_restore adjustment_credit].freeze
  DEBIT_TYPES = %w[redeem expire earn_reversal adjustment_debit].freeze
  belongs_to :loyalty_account
  belongs_to :branch, default: -> { source.try(:branch) || Current.branch || Branch.default_branch }
  belongs_to :source, polymorphic: true, optional: true
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :reversal_of, class_name: "LoyaltyLedgerEntry", optional: true
  has_many :point_allocations, foreign_key: :debit_entry_id, dependent: :restrict_with_error
  has_many :consumption_allocations, class_name: "LoyaltyPointAllocation", foreign_key: :earn_entry_id, dependent: :restrict_with_error
  enum :entry_type, { earn: 0, redeem: 1, expire: 2, earn_reversal: 3, redemption_restore: 4,
    adjustment_credit: 5, adjustment_debit: 6 }, validate: true
  validates :points, numericality: { only_integer: true, greater_than: 0 }
  validates :reason, :occurred_at, :idempotency_key, presence: true
  validates :idempotency_key, uniqueness: true
  validate { errors.add(:expires_at, "يجب أن يلي وقت القيد") if expires_at && occurred_at && expires_at <= occurred_at }
  before_update { throw :abort }
  before_destroy { throw :abort }

  def self.balance_sql
    sanitize_sql_array([ "CASE WHEN entry_type IN (?) THEN points ELSE -points END", CREDIT_TYPES.map { |type| entry_types.fetch(type) } ])
  end
  def credit? = entry_type.in?(CREDIT_TYPES)
  def remaining_points = points - consumption_allocations.sum(:points)
end
