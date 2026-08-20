module Reports
  # Operational counts of locally configured rule matches. These are workflow metrics for the
  # pharmacy team, not epidemiological or medical analytics.
  class DrugSafetySummary
    Result = Data.define(:cards, :severity_counts, :rule_type_counts, :status_counts, :open_blocking,
      :override_by_pharmacist, :rule_usage, :substitution_findings, :evaluation_count)

    def initialize(range) = @range = range

    def call
      findings = DrugSafetyFinding.where(created_at: @range.range)
      evaluations = DrugSafetyEvaluation.where(created_at: @range.range)
      status_counts = findings.group(:status).count
      Result.new(
        cards: { findings: findings.count, blocking: findings.where(blocking: true).count,
          open_blocking: open_blocking_scope.count, overrides: status_counts.fetch("overridden", 0) },
        severity_counts: findings.group(:severity).count,
        rule_type_counts: findings.joins(:drug_safety_rule).group("drug_safety_rules.rule_type").count,
        status_counts:,
        open_blocking: open_blocking_scope.includes(:drug_safety_rule,
          prescription_review_item: [ :original_product, { prescription_review: :reviewable } ]).ranked.limit(25),
        override_by_pharmacist: override_by_pharmacist(findings),
        rule_usage: rule_usage(findings),
        substitution_findings: findings.joins(:drug_safety_evaluation)
          .where(drug_safety_evaluations: { trigger: DrugSafetyEvaluation.triggers[:substitution_recorded] })
          .where(carried_from_id: nil).count,
        evaluation_count: evaluations.count
      )
    end

    private

    def open_blocking_scope = DrugSafetyFinding.current.unresolved.blocking

    def override_by_pharmacist(findings)
      counts = findings.where(status: :overridden).where.not(resolved_by_id: nil).group(:resolved_by_id).count
      names = User.where(id: counts.keys).index_by(&:id)
      counts.transform_keys { |id| names[id]&.full_name || "—" }
    end

    def rule_usage(findings)
      findings.joins(:drug_safety_rule)
        .group("drug_safety_rules.code", "drug_safety_rules.version", "drug_safety_rules.arabic_label")
        .order(Arel.sql("COUNT(*) DESC")).limit(15).count
        .map { |(code, version, label), count| { identity: "#{code} v#{version}", label:, count: } }
    end
  end
end
