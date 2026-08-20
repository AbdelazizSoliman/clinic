class PrescriptionReview < ApplicationRecord
  belongs_to :reviewable, polymorphic: true
  belongs_to :started_by, class_name: "User", optional: true
  has_many :items, class_name: "PrescriptionReviewItem", dependent: :restrict_with_error
  has_many :decisions, through: :items
  has_many :safety_evaluations, class_name: "DrugSafetyEvaluation", dependent: :restrict_with_error

  enum :status, { pending: 0, under_review: 1, completed: 2 }, default: :pending, validate: true

  validates :reviewable_id, uniqueness: { scope: :reviewable_type }
  validate :timestamps_are_consistent
  validate :completed_review_is_immutable, on: :update

  def online? = reviewable_type == "Prescription"
  def pos? = reviewable_type == "PosSale"
  def all_items_decided? = items.exists? && items.where(status: %i[pending under_review]).none?
  def current_safety_evaluation = safety_evaluations.current.order(:sequence).last
  def patient = online? ? reviewable.user : nil

  private

  def timestamps_are_consistent
    errors.add(:started_at, "مطلوب") if under_review? && started_at.blank?
    errors.add(:completed_at, "مطلوب") if completed? && completed_at.blank?
  end

  def completed_review_is_immutable
    return unless status_was == "completed"
    errors.add(:base, "المراجعة المكتملة غير قابلة للتعديل") if changes.except("updated_at").any?
  end
end
