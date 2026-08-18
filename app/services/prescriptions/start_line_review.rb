module Prescriptions
  class StartLineReview
    Result = Data.define(:success?, :item, :errors)

    def initialize(item:, actor:, lock_version: nil)
      @item, @actor, @lock_version = item, actor, lock_version
    end

    def call
      return failure("بدء المراجعة متاح للصيدلي فقط") unless @actor&.can_make_prescription_decisions?
      PrescriptionReviewItem.transaction do
        @item.prescription_review.lock!
        @item.lock!
        raise ActiveRecord::StaleObjectError.new(@item, "review") if @lock_version && @item.lock_version != @lock_version.to_i
        return success if @item.under_review?
        return failure("تم اتخاذ قرار نهائي لهذا البند") unless @item.pending?
        review = @item.prescription_review
        review.update!(status: :under_review, started_at: Time.current, started_by: @actor) if review.pending?
        review.reviewable.update!(status: :under_review) if review.online? && review.reviewable.submitted?
        from = @item.status
        @item.update!(status: :under_review)
        @item.decisions.create!(actor: @actor, from_status: from, to_status: "under_review")
        audit("prescription_line_review_started")
        DrugSafety::Reevaluate.call(review, trigger: :line_review_started, actor: @actor)
      end
      success
    rescue ActiveRecord::StaleObjectError
      failure("تم تحديث البند بواسطة مستخدم آخر؛ أعد تحميل الصفحة")
    end

    private

    def audit(action)
      AdminAuditEvent.create!(actor: @actor, auditable: @item.prescription_review, action:,
        metadata: { review_item_id: @item.id })
    end
    def success = Result.new(success?: true, item: @item, errors: [])
    def failure(message) = Result.new(success?: false, item: @item, errors: [ message ])
  end
end
