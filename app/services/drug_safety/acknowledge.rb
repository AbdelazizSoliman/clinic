module DrugSafety
  # Records a pharmacist's clinical acknowledgement or documented override of one finding.
  # Only pharmacists may resolve findings, and only on the current clinical context.
  class Acknowledge
    Result = Data.define(:success?, :finding, :errors)
    ACTIONS = %w[acknowledged overridden].freeze

    def initialize(finding:, actor:, action:, reason:, lock_version: nil)
      @finding = finding
      @actor = actor
      @action = action.to_s
      @reason = reason.to_s.squish.presence
      @lock_version = lock_version
    end

    def call
      return failure("إقرار تنبيهات السلامة متاح للصيدلي فقط") unless @actor&.can_resolve_safety_findings?
      return failure("إجراء غير صحيح") unless ACTIONS.include?(@action)
      return failure("هذا التنبيه لم يعد ضمن السياق السريري الحالي") unless @finding.drug_safety_evaluation.current?
      return failure("سبب موثق مطلوب لهذا التنبيه") if @reason.blank? && reason_required?

      review = @finding.prescription_review_item.prescription_review
      DrugSafetyFinding.transaction do
        @finding.lock!
        raise ActiveRecord::StaleObjectError.new(@finding, "acknowledge") if stale?
        return success if @finding.resolved?
        return failure("لا يمكن إقرار تنبيه لم يعد منطبقًا") if @finding.no_longer_applicable?

        @finding.update!(status: @action, resolved_at: Time.current, resolved_by: @actor)
        @finding.acknowledgements.create!(pharmacist: @actor, action: @action, reason: @reason)
        audit(review)
      end
      finalize_if_clear(review)
      success
    rescue ActiveRecord::StaleObjectError
      failure("تم تحديث التنبيه بواسطة مستخدم آخر؛ أعد تحميل الصفحة")
    rescue ActiveRecord::RecordInvalid => error
      failure(error.record.errors.full_messages)
    end

    private

    def reason_required? = @action == "overridden" || @finding.blocking?
    def stale? = @lock_version.present? && @finding.lock_version != @lock_version.to_i

    # Online reviews wait for a clear safety gate before the order-level decision is finalised.
    def finalize_if_clear(review)
      return unless review.online? && review.under_review?
      return unless review.all_items_decided? && Gate.blocking_findings(review.reload).none?
      Prescriptions::FinalizeReview.call(review, actor: @actor)
    end

    def audit(review)
      AdminAuditEvent.create!(actor: @actor, auditable: review,
        action: @action == "overridden" ? "drug_safety_finding_overridden" : "drug_safety_finding_acknowledged",
        metadata: { finding_id: @finding.id, rule: @finding.rule_identity, severity: @finding.severity,
          blocking: @finding.blocking, review_item_id: @finding.prescription_review_item_id })
    end

    def success = Result.new(success?: true, finding: @finding, errors: [])
    def failure(messages) = Result.new(success?: false, finding: @finding, errors: Array(messages))
  end
end
