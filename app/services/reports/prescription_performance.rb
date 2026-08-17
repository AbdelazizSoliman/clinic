module Reports
  class PrescriptionPerformance
    Result = Data.define(:status_counts, :approval_rate, :rejection_rate, :average_review_seconds, :review_sample_count,
      :oldest, :follow_ups, :item_status_counts, :substitution_count, :pharmacist_workload)
    def initialize(range) = @range = range
    def call
      scope = Prescription.where(submitted_at: @range.range)
      counts = scope.group(:status).count
      reviewed = scope.where.not(reviewed_at: nil)
      total_final = counts.values_at("approved", "partially_approved", "rejected").compact.sum
      items = PrescriptionReviewItem.joins(:prescription_review)
        .where(prescription_review: { reviewable_type: "Prescription", reviewable_id: scope.select(:id) })
      Result.new(status_counts: counts,
        approval_rate: total_final.zero? ? nil : (counts.fetch("approved", 0) * 100.0 / total_final).round(1),
        rejection_rate: total_final.zero? ? nil : (counts.fetch("rejected", 0) * 100.0 / total_final).round(1),
        average_review_seconds: reviewed.average("EXTRACT(EPOCH FROM (reviewed_at - submitted_at))")&.to_i,
        review_sample_count: reviewed.count, oldest: scope.where(status: %i[submitted under_review]).order(:submitted_at).limit(10),
        follow_ups: OrderFollowUp.where(created_at: @range.range, kind: :prescription_clarification).group(:status).count,
        item_status_counts: items.group(:status).count,
        substitution_count: items.where(status: :substituted).count,
        pharmacist_workload: pharmacist_workload(items))
    end

    private

    def pharmacist_workload(items)
      counts_by_id = items.where.not(reviewed_by_id: nil).group(:reviewed_by_id).count
      names = User.where(id: counts_by_id.keys).index_by(&:id)
      counts_by_id.transform_keys { |id| names[id]&.full_name || "—" }
    end
  end
end
