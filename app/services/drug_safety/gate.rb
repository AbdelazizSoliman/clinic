module DrugSafety
  # Read-only dispensing gate. Blocking findings are those the locally configured rule set
  # marks as blocking and that no pharmacist has acknowledged or overridden yet.
  module Gate
    module_function

    def current_findings(review)
      evaluation = review.current_safety_evaluation
      return DrugSafetyFinding.none unless evaluation
      evaluation.findings.includes(:drug_safety_rule, :resolved_by).ranked
    end

    def blocking_findings(review) = current_findings(review).select(&:blocks_dispensing?)

    def blocking_findings_for_item(item)
      blocking_findings(item.prescription_review).select { |finding| finding.involved_review_item_ids.include?(item.id) }
    end

    def blocked?(review) = blocking_findings(review).any?
    def blocked_item?(item) = blocking_findings_for_item(item).any?

    def blocked_message(findings)
      "تنبيهات سلامة حرجة تمنع الصرف حتى يقرها الصيدلي: #{findings.map(&:rule_identity).uniq.join('، ')}"
    end
  end
end
