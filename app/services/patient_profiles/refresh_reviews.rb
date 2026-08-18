module PatientProfiles
  # Clinical facts about a patient changed, so every prescription review that is still open
  # for that patient is re-evaluated against the new context.
  class RefreshReviews
    def self.call(user, actor: nil)
      reviews = PrescriptionReview.where(reviewable_type: "Prescription",
        reviewable_id: Prescription.where(user:).select(:id)).where.not(status: :completed)
      reviews.find_each do |review|
        DrugSafety::Reevaluate.call(review, trigger: :patient_data_changed, actor:)
      end
      reviews.count
    end
  end
end
