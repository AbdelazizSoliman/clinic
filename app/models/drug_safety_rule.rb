# An immutable clinical rule version. Editing a published rule never mutates history:
# a new version row is created and the previous version is retired, so every finding
# stays tied to the exact rule text and severity that produced it.
class DrugSafetyRule < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  has_many :conditions, class_name: "DrugSafetyRuleCondition", dependent: :destroy, inverse_of: :drug_safety_rule
  has_many :findings, class_name: "DrugSafetyFinding", dependent: :restrict_with_error

  accepts_nested_attributes_for :conditions, allow_destroy: true,
    reject_if: ->(attributes) { attributes[:condition_type].blank? }

  enum :rule_type, DrugSafety::RULE_TYPES, validate: true
  enum :severity, DrugSafety::SEVERITIES, default: :caution, validate: true

  scope :active, -> { where(active: true) }
  scope :effective_at, ->(time) {
    where("effective_from IS NULL OR effective_from <= ?", time).where("effective_to IS NULL OR effective_to > ?", time)
  }
  scope :evaluable_at, ->(time) { active.effective_at(time).where(rule_type: DrugSafety::SUPPORTED_RULE_TYPES) }
  scope :ordered, -> { order(Arel.sql("severity DESC"), :code, :version) }

  validates :code, presence: true, format: { with: /\A[A-Z0-9][A-Z0-9\-]*\z/ }, length: { maximum: 40 },
    uniqueness: { scope: %i[organization_id version] }
  validates :version, numericality: { only_integer: true, greater_than: 0 }
  validates :name, :arabic_label, presence: true, length: { maximum: 160 }
  validates :description, presence: true, length: { maximum: 2000 }
  validates :evidence_note, :internal_notes, length: { maximum: 2000 }, allow_blank: true
  validates :active, :blocking, inclusion: { in: [ true, false ] }
  validate :blocking_requires_actionable_severity
  validate :supported_type_when_active
  validate :effective_window_is_ordered
  validate :single_active_version_per_code
  validate :conditions_match_rule_type
  validate :published_rule_is_immutable, on: :update

  def supported? = DrugSafety::SUPPORTED_RULE_TYPES.include?(rule_type)
  def published? = activated_at.present?
  def patient_dependent? = DrugSafety::PATIENT_DEPENDENT_RULE_TYPES.include?(rule_type)
  def identity = "#{code} v#{version}"
  def severity_label = DrugSafety::SEVERITY_LABELS.fetch(severity, severity)
  def rule_type_label = DrugSafety::RULE_TYPE_LABELS.fetch(rule_type, rule_type)

  def condition_for(role:, condition_type:)
    conditions.detect { |condition| condition.role == role.to_s && condition.condition_type == condition_type.to_s }
  end

  def primary_ingredient_id = condition_for(role: :primary, condition_type: :active_ingredient)&.active_ingredient_id
  def secondary_ingredient_id = condition_for(role: :secondary, condition_type: :active_ingredient)&.active_ingredient_id
  def minimum_age_years = condition_for(role: :primary, condition_type: :minimum_age_years)&.numeric_value
  def maximum_age_years = condition_for(role: :primary, condition_type: :maximum_age_years)&.numeric_value
  def state_key = condition_for(role: :primary, condition_type: :patient_state)&.state_key

  def snapshot
    { "code" => code, "version" => version, "name" => name, "arabic_label" => arabic_label,
      "rule_type" => rule_type, "severity" => severity, "blocking" => blocking,
      "description" => description, "evidence_note" => evidence_note }
  end

  private

  def blocking_requires_actionable_severity
    return unless blocking?
    errors.add(:blocking, "يتطلب خطورة «مهم» أو «حرج»") unless DrugSafety::ACKNOWLEDGEABLE_SEVERITIES.include?(severity)
  end

  def supported_type_when_active
    return unless active?
    errors.add(:rule_type, "غير مدعوم للتقييم في هذه المرحلة") unless supported?
  end

  def effective_window_is_ordered
    return if effective_from.blank? || effective_to.blank?
    errors.add(:effective_to, "يجب أن يكون بعد بداية السريان") unless effective_to > effective_from
  end

  def single_active_version_per_code
    return unless active? && code.present?
    scope = self.class.unscoped.active.where(organization_id:, code:)
    scope = scope.where.not(id:) if persisted?
    errors.add(:active, "يوجد إصدار نشط آخر لنفس الرمز") if scope.exists?
  end

  def conditions_match_rule_type
    return if rule_type.blank?
    candidates = conditions.reject(&:marked_for_destruction?)
    ingredients = candidates.count { |condition| condition.active_ingredient? }
    case rule_type
    when "drug_interaction"
      errors.add(:conditions, "التداخل الدوائي يحتاج مادتين فعالتين مختلفتين") unless interaction_pair_valid?(candidates)
    when "duplicate_therapy", "allergy"
      errors.add(:conditions, "هذا النوع يعمل على كل المواد الفعالة ولا يقبل شروط مواد") if ingredients.positive?
    when "age_restriction"
      errors.add(:conditions, "القيد العمري يحتاج مادة فعالة واحدة") unless ingredients == 1
      errors.add(:conditions, "حدد حدًا أدنى أو أقصى للعمر") if minimum_age_years.nil? && maximum_age_years.nil?
      errors.add(:conditions, "الحد الأدنى يجب أن يقل عن الأقصى") if age_bounds_inverted?
    when *DrugSafety::PATIENT_STATE_RULE_TYPES
      errors.add(:conditions, "هذا النوع يحتاج مادة فعالة واحدة") unless ingredients == 1
      errors.add(:conditions, "حدد حالة سريرية مسجلة") unless DrugSafety::STATE_KEYS.include?(state_key)
    end
  end

  def interaction_pair_valid?(candidates)
    pair = candidates.select(&:active_ingredient?)
    pair.size == 2 && pair.map(&:role).sort == %w[primary secondary] &&
      pair.map(&:active_ingredient_id).uniq.size == 2
  end

  def age_bounds_inverted?
    minimum_age_years.present? && maximum_age_years.present? && minimum_age_years >= maximum_age_years
  end

  # Once published, only the lifecycle columns may change. Clinical content changes go into a new version.
  def published_rule_is_immutable
    return unless activated_at_was.present?
    locked = changes.keys - %w[active activated_at retired_at internal_notes lock_version updated_at]
    errors.add(:base, "القاعدة المنشورة غير قابلة للتعديل — أنشئ إصدارًا جديدًا") if locked.any?
  end
end
