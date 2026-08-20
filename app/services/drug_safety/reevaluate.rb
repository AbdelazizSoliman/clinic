module DrugSafety
  # Persists one evaluation of a prescription review. Idempotent: when neither the clinical
  # context nor the effective rule set changed, the existing current evaluation is returned
  # unchanged and nothing is written.
  class Reevaluate
    def self.call(review, trigger: :context_built, actor: nil, at: Time.current)
      new(review, trigger:, actor:, at:).call
    end

    def initialize(review, trigger:, actor:, at:)
      @review = review
      @trigger = trigger.to_s
      @actor = actor
      @at = at
    end

    def call
      context = Context.build(@review, evaluated_at: @at)
      rule_set = RuleSet.effective_at(@at)
      context_digest = context.digest
      ruleset_digest = rule_set.digest

      current = @review.safety_evaluations.current.order(:sequence).last
      return current if current&.matches?(context_digest:, ruleset_digest:)

      drafts = Evaluate.call(context:, rule_set:)
      persist(current, drafts, context_digest, ruleset_digest)
    end

    private

    def persist(previous, drafts, context_digest, ruleset_digest)
      evaluation = nil
      DrugSafetyEvaluation.transaction do
        @review.lock!
        latest = @review.safety_evaluations.order(:sequence).last
        return latest if latest&.current? && latest.matches?(context_digest:, ruleset_digest:)

        evaluation = @review.safety_evaluations.create!(sequence: (latest&.sequence || 0) + 1,
          context_digest:, ruleset_digest:, trigger: @trigger, actor: @actor, evaluated_at: @at,
          findings_count: drafts.size, blocking_count: drafts.count(&:blocking))
        previous_findings = index_previous(previous || latest)
        carried = drafts.map { |draft| create_finding(evaluation, draft, previous_findings[draft.dedupe_key]) }
        close_outdated(previous_findings, drafts.map(&:dedupe_key))
        @review.safety_evaluations.where.not(id: evaluation.id).where(superseded_at: nil).update_all(superseded_at: @at)
        audit(evaluation, carried)
      end
      evaluation
    end

    def index_previous(previous)
      return {} unless previous
      previous.findings.includes(:resolved_by).index_by(&:dedupe_key)
    end

    # Resolution carries forward only when the matched clinical facts are byte-identical
    # (same rule version, same lines, same products, same ingredients). Any substitution or
    # product change produces a different key, so a new context is never cleared by an old decision.
    def create_finding(evaluation, draft, previous)
      inherited = previous if previous&.resolved? && previous.drug_safety_rule_id == draft.rule.id
      evaluation.findings.create!(drug_safety_rule: draft.rule, prescription_review_item_id: draft.review_item_id,
        related_review_item_id: draft.related_review_item_id, severity: draft.severity, blocking: draft.blocking,
        explanation: draft.explanation, rule_snapshot: draft.rule.snapshot, matched_facts: draft.matched_facts,
        dedupe_key: draft.dedupe_key, status: inherited&.status || "open", resolved_at: inherited&.resolved_at,
        resolved_by: inherited&.resolved_by, carried_from: inherited)
    end

    def close_outdated(previous_findings, live_keys)
      outdated = previous_findings.reject { |key, finding| live_keys.include?(key) || !finding.open? }
      outdated.each_value { |finding| finding.update!(status: :no_longer_applicable, resolved_at: @at) }
    end

    def audit(evaluation, findings)
      return unless @actor
      AdminAuditEvent.create!(actor: @actor, auditable: @review, action: "drug_safety_evaluated",
        metadata: { evaluation_id: evaluation.id, sequence: evaluation.sequence, trigger: @trigger,
          findings: evaluation.findings_count, blocking: evaluation.blocking_count,
          rules: findings.map { |finding| finding.rule_identity }.uniq })
    end
  end
end
