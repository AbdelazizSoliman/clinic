# Shared vocabulary for the pharmacist decision-support engine.
#
# The engine only ever *detects* and *explains* locally configured rules. It never
# prescribes, diagnoses, recommends treatment, or clears a clinical decision on its own.
module DrugSafety
  SEVERITIES = { info: 0, caution: 1, major: 2, critical: 3 }.freeze

  RULE_TYPES = {
    drug_interaction: 0, duplicate_therapy: 1, allergy: 2, age_restriction: 3,
    pregnancy_caution: 4, lactation_caution: 5, contraindication: 6,
    renal_caution: 7, hepatic_caution: 8, dose_limit: 9
  }.freeze

  # Rule types the repository holds enough structured data to evaluate deterministically.
  # The remaining types stay defined as extension points and cannot be activated.
  SUPPORTED_RULE_TYPES = %w[drug_interaction duplicate_therapy allergy age_restriction
    pregnancy_caution lactation_caution contraindication].freeze

  PATIENT_STATE_RULE_TYPES = %w[pregnancy_caution lactation_caution contraindication].freeze
  PATIENT_DEPENDENT_RULE_TYPES = (PATIENT_STATE_RULE_TYPES + %w[allergy age_restriction]).freeze

  STATE_KEYS = %w[pregnant lactating].freeze

  # Severities at or above this level require an explicit pharmacist action before dispensing.
  ACKNOWLEDGEABLE_SEVERITIES = %w[major critical].freeze

  DISCLAIMER = "تنبيه دعم قرار فقط — القرار السريري النهائي مسؤولية الصيدلي المرخص.".freeze

  SEVERITY_LABELS = {
    "info" => "للعلم", "caution" => "انتبه", "major" => "مهم — يتطلب إقرارًا", "critical" => "حرج — يوقف الصرف"
  }.freeze

  RULE_TYPE_LABELS = {
    "drug_interaction" => "تداخل دوائي", "duplicate_therapy" => "ازدواج علاجي", "allergy" => "تعارض حساسية",
    "age_restriction" => "قيد عمري", "pregnancy_caution" => "تنبيه حمل", "lactation_caution" => "تنبيه رضاعة",
    "contraindication" => "مانع استعمال مسجل", "renal_caution" => "تنبيه كلوي (غير مدعوم)",
    "hepatic_caution" => "تنبيه كبدي (غير مدعوم)", "dose_limit" => "حد جرعة (غير مدعوم)"
  }.freeze

  FINDING_STATUS_LABELS = {
    "open" => "مفتوح", "acknowledged" => "مُقَر", "overridden" => "تجاوز موثق", "no_longer_applicable" => "لم يعد منطبقًا"
  }.freeze

  def self.severity_rank(severity) = SEVERITIES.fetch(severity.to_sym, 0)
end
