class DrugSafetyRuleCondition < ApplicationRecord
  MAX_AGE_YEARS = 130

  belongs_to :drug_safety_rule, inverse_of: :conditions
  belongs_to :active_ingredient, optional: true

  enum :role, { primary: 0, secondary: 1 }, default: :primary, validate: true
  enum :condition_type, { active_ingredient: 0, patient_state: 1, minimum_age_years: 2, maximum_age_years: 3 },
    prefix: true, validate: true

  validates :condition_type, uniqueness: { scope: %i[drug_safety_rule_id role] }
  validate :payload_matches_condition_type

  def active_ingredient? = condition_type_active_ingredient?

  def description
    case condition_type
    when "active_ingredient" then "مادة فعالة: #{active_ingredient&.name}"
    when "patient_state" then "حالة سريرية مسجلة: #{state_key}"
    when "minimum_age_years" then "حد أدنى للعمر: #{numeric_value} سنة"
    when "maximum_age_years" then "حد أقصى للعمر: #{numeric_value} سنة"
    end
  end

  private

  def payload_matches_condition_type
    case condition_type
    when "active_ingredient"
      errors.add(:active_ingredient, "مطلوبة") if active_ingredient_id.blank?
      errors.add(:base, "شرط المادة الفعالة لا يقبل قيمًا أخرى") if state_key.present? || numeric_value.present?
    when "patient_state"
      errors.add(:state_key, "غير مدعومة") unless DrugSafety::STATE_KEYS.include?(state_key)
      errors.add(:base, "شرط الحالة لا يقبل قيمًا أخرى") if active_ingredient_id.present? || numeric_value.present?
    when "minimum_age_years", "maximum_age_years"
      errors.add(:numeric_value, "يجب أن تكون بين 0 و#{MAX_AGE_YEARS}") unless numeric_value&.between?(0, MAX_AGE_YEARS)
      errors.add(:base, "شرط العمر لا يقبل قيمًا أخرى") if active_ingredient_id.present? || state_key.present?
    end
  end
end
