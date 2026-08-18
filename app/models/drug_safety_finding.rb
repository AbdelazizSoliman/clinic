# A rule match recorded against one clinical context. Findings are never deleted: when the
# context changes a new evaluation is written and the superseded findings stay readable.
class DrugSafetyFinding < ApplicationRecord
  belongs_to :drug_safety_evaluation
  belongs_to :drug_safety_rule
  belongs_to :prescription_review_item
  belongs_to :related_review_item, class_name: "PrescriptionReviewItem", optional: true
  belongs_to :carried_from, class_name: "DrugSafetyFinding", optional: true
  belongs_to :resolved_by, class_name: "User", optional: true
  has_many :acknowledgements, class_name: "DrugSafetyAcknowledgement", dependent: :destroy,
    foreign_key: :drug_safety_finding_id, inverse_of: :finding

  enum :severity, DrugSafety::SEVERITIES, validate: true
  enum :status, { open: 0, acknowledged: 1, overridden: 2, no_longer_applicable: 3 }, default: :open, validate: true

  scope :current, -> { joins(:drug_safety_evaluation).where(drug_safety_evaluations: { superseded_at: nil }) }
  scope :unresolved, -> { where(status: :open) }
  scope :resolved_by_pharmacist, -> { where(status: %i[acknowledged overridden]) }
  scope :blocking, -> { where(blocking: true) }
  scope :ranked, -> { order(Arel.sql("severity DESC"), :dedupe_key) }

  validates :explanation, presence: true, length: { maximum: 2000 }
  validates :dedupe_key, presence: true, uniqueness: { scope: :drug_safety_evaluation_id }
  validates :blocking, inclusion: { in: [ true, false ] }
  validate :blocking_requires_actionable_severity
  validate :resolution_is_consistent

  def requires_acknowledgement? = DrugSafety::ACKNOWLEDGEABLE_SEVERITIES.include?(severity)
  def resolved? = acknowledged? || overridden?
  def blocks_dispensing? = blocking? && open?
  def severity_label = DrugSafety::SEVERITY_LABELS.fetch(severity, severity)
  def status_label = DrugSafety::FINDING_STATUS_LABELS.fetch(status, status)
  def rule_type = rule_snapshot["rule_type"].to_s
  def rule_type_label = DrugSafety::RULE_TYPE_LABELS.fetch(rule_type, rule_type)
  def rule_identity = "#{rule_snapshot['code']} v#{rule_snapshot['version']}"
  def involved_review_item_ids = [ prescription_review_item_id, related_review_item_id ].compact

  private

  def blocking_requires_actionable_severity
    return unless blocking?
    errors.add(:blocking, "يتطلب خطورة «مهم» أو «حرج»") unless requires_acknowledgement?
  end

  def resolution_is_consistent
    if resolved?
      errors.add(:resolved_by, "مطلوب") unless resolved_by&.can_make_prescription_decisions?
      errors.add(:resolved_at, "مطلوب") if resolved_at.blank?
    elsif no_longer_applicable?
      errors.add(:resolved_at, "مطلوب") if resolved_at.blank?
      errors.add(:resolved_by, "لا يسجل مع الإغلاق التلقائي") if resolved_by_id
    elsif resolved_by_id || resolved_at
      errors.add(:base, "لا يسجل إغلاق قبل إجراء الصيدلي")
    end
  end
end
