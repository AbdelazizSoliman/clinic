# Append-only record of the pharmacist action taken on a finding.
class DrugSafetyAcknowledgement < ApplicationRecord
  belongs_to :finding, class_name: "DrugSafetyFinding", foreign_key: :drug_safety_finding_id, inverse_of: :acknowledgements
  belongs_to :pharmacist, class_name: "User"

  enum :action, { acknowledged: 0, overridden: 1 }, validate: true

  validates :reason, length: { maximum: 1000 }, allow_blank: true
  validates :reason, presence: true, if: :reason_required?
  validate { errors.add(:pharmacist, "يجب أن يكون صيدليًا") unless pharmacist&.can_make_prescription_decisions? }
  before_update { throw :abort }
  # Never deletable on its own; only cascades away with a draft line that was never dispensed.
  before_destroy { throw :abort unless destroyed_by_association }

  def action_label = overridden? ? "تجاوز موثق" : "إقرار"

  private

  def reason_required? = overridden? || finding&.blocking?
end
