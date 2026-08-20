class PatientAllergy < ApplicationRecord
  belongs_to :patient_clinical_profile
  belongs_to :active_ingredient
  belongs_to :recorded_by, class_name: "User"

  enum :severity, DrugSafety::SEVERITIES, default: :major, validate: true

  scope :active, -> { where(active: true) }

  validates :active_ingredient_id, uniqueness: { scope: :patient_clinical_profile_id }
  validates :recorded_at, presence: true
  validates :notes, length: { maximum: 1000 }, allow_blank: true
  validates :active, inclusion: { in: [ true, false ] }
  validate { errors.add(:recorded_by, "يجب أن يكون صيدليًا") unless recorded_by&.can_make_prescription_decisions? }
end
