# Structured, pharmacist-recorded clinical facts used by the drug safety rules engine.
# Nothing here is inferred: every field is entered explicitly by a pharmacist.
class PatientClinicalProfile < ApplicationRecord
  MAX_AGE_YEARS = 130

  belongs_to :user
  belongs_to :recorded_by, class_name: "User"
  has_many :allergies, class_name: "PatientAllergy", dependent: :destroy

  enum :pregnancy_status, { pregnancy_unknown: 0, not_pregnant: 1, pregnant: 2 }, default: :pregnancy_unknown, validate: true
  enum :lactation_status, { lactation_unknown: 0, not_lactating: 1, lactating: 2 }, default: :lactation_unknown, validate: true

  validates :user_id, uniqueness: true
  validates :recorded_at, presence: true
  validates :notes, length: { maximum: 2000 }, allow_blank: true
  validate :date_of_birth_is_plausible
  validate { errors.add(:recorded_by, "يجب أن يكون صيدليًا") unless recorded_by&.can_make_prescription_decisions? }

  def age_years_on(date)
    return nil if date_of_birth.blank? || date.blank?
    years = date.year - date_of_birth.year
    years -= 1 if date < date_of_birth + years.years
    years
  end

  def state_flags
    { "pregnant" => pregnant?, "lactating" => lactating? }
  end

  private

  def date_of_birth_is_plausible
    return if date_of_birth.blank?
    errors.add(:date_of_birth, "لا يمكن أن يكون في المستقبل") if date_of_birth > Date.current
    errors.add(:date_of_birth, "غير منطقي") if date_of_birth < Date.current - MAX_AGE_YEARS.years
  end
end
