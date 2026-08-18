# One deterministic run of the rules engine over a prescription review's clinical context.
# A new evaluation is only created when the context or the active rule set actually changed.
class DrugSafetyEvaluation < ApplicationRecord
  belongs_to :prescription_review
  belongs_to :actor, class_name: "User", optional: true
  has_many :findings, class_name: "DrugSafetyFinding", dependent: :restrict_with_error

  enum :trigger, { context_built: 0, line_review_started: 1, decision_recorded: 2, substitution_recorded: 3,
    cart_changed: 4, patient_data_changed: 5, rules_changed: 6, manual: 7 }, default: :context_built, validate: true

  scope :current, -> { where(superseded_at: nil) }
  scope :chronological, -> { order(:sequence) }

  validates :sequence, numericality: { only_integer: true, greater_than: 0 }
  validates :sequence, uniqueness: { scope: :prescription_review_id }
  validates :context_digest, :ruleset_digest, :evaluated_at, presence: true
  validates :findings_count, :blocking_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate { errors.add(:blocking_count, "لا يتجاوز إجمالي النتائج") if blocking_count.to_i > findings_count.to_i }

  def current? = superseded_at.nil?
  def matches?(context_digest:, ruleset_digest:)
    self.context_digest == context_digest && self.ruleset_digest == ruleset_digest
  end
end
