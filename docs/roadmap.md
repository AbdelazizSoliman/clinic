# Roadmap status

- Phase 18 — Pharmacy POS: complete.
- Phase 19 — per-item prescription review and therapeutic substitution: complete. See [prescription_review.md](prescription_review.md).
- Phase 20 — drug safety rules engine: complete. See [drug_safety_rules.md](drug_safety_rules.md).
  Supported rule types: interaction, duplicate therapy, allergy, age, pregnancy,
  lactation, contraindication. Renal, hepatic and dose-limit rules stay deferred
  because the application stores no structured renal/hepatic status and no
  structured dose, frequency or duration.
- Phase 21 — advanced Arabic search: complete. See [search.md](search.md).
  PostgreSQL + pg_trgm only; no external search service. Transliteration, stemming and
  query-history suggestions remain deferred.
- Phase 22 — append-only customer/POS returns, reverse batch logistics, controlled refunds, receipts and reporting: implemented.
- Phase 23 — supplier returns/credits, real gateway integration, loyalty reversal, recall and multi-branch reverse logistics: deferred.
