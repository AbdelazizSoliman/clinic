module DrugSafetyHelper
  # Severity is never conveyed by colour alone: every badge carries a text label and a symbol.
  SEVERITY_STYLES = {
    "info" => [ "bg-slate-100 text-slate-900 border-slate-400", "ⓘ" ],
    "caution" => [ "bg-amber-50 text-amber-950 border-amber-500", "△" ],
    "major" => [ "bg-orange-50 text-orange-950 border-orange-600", "◆" ],
    "critical" => [ "bg-rose-50 text-rose-950 border-rose-700", "■" ]
  }.freeze

  def safety_severity_badge(severity)
    classes, symbol = SEVERITY_STYLES.fetch(severity.to_s, SEVERITY_STYLES["info"])
    tag.span(class: "inline-flex items-center gap-1 rounded-full border-2 px-3 py-1 text-sm font-black #{classes}") do
      safe_join([ tag.span(symbol, aria: { hidden: true }), DrugSafety::SEVERITY_LABELS.fetch(severity.to_s, severity.to_s) ], " ")
    end
  end

  def safety_status_badge(finding)
    tag.span(finding.status_label, class: "rounded-full border px-3 py-1 text-xs font-bold #{finding.open? ? 'border-slate-400' : 'border-emerald-600 text-emerald-800'}")
  end

  def safety_findings_for(findings, item)
    findings.select { |finding| finding.involved_review_item_ids.include?(item.id) }
  end
end
