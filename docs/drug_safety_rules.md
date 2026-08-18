# Drug safety rules engine — Phase 20

Phase 20 adds a deterministic, pharmacist-facing decision-support engine on top
of the Phase 19 per-item prescription review. It detects clinically relevant
conditions defined by **locally configured rules** and surfaces them to the
pharmacist during review and at the POS counter.

## Safety boundary

The engine is decision support only. It **may**:

- detect a match against a locally configured rule
- classify the configured severity
- explain, in Arabic, which structured facts matched
- require an explicit pharmacist acknowledgement
- block dispensing for rules configured as blocking, until a pharmacist resolves them
- record a documented override reason

It **must not, and does not**:

- prescribe, diagnose, or recommend treatment or a dose
- auto-substitute, auto-approve, or auto-reject anything
- replace or outrank the pharmacist
- infer clinical facts from free text, notes, gender, age, or order history
- use generative AI, external drug databases, or any network lookup

Every finding rendered in the UI carries the fixed disclaimer
(`DrugSafety::DISCLAIMER`): *"تنبيه دعم قرار فقط — القرار السريري النهائي مسؤولية
الصيدلي المرخص."* The absence of a finding is explicitly presented as "no rule
matched", never as "safe".

Rules are data, never code: a rule is a row plus typed condition rows. There is
no expression language, no SQL fragment, and no user-supplied executable input
anywhere in the evaluation path.

## Structured clinical data actually available

| Fact | Source | Status |
| --- | --- | --- |
| Active ingredient identity | `active_ingredients` + `product_active_ingredients` | Added in Phase 20 |
| Dispensed vs prescribed product | `prescription_review_items` (Phase 19) | Existing |
| Patient date of birth | `patient_clinical_profiles.date_of_birth` | Added in Phase 20 |
| Pregnancy / lactation state | `patient_clinical_profiles` enums | Added in Phase 20 |
| Allergies | `patient_allergies` keyed on active ingredient | Added in Phase 20 |
| Renal / hepatic status | — | **Not stored** |
| Dose, frequency, duration, route | — | **Not stored** |

`products.active_ingredient` is a free-text catalogue string. It is display
metadata and is **never** matched against rules.

## Supported and unsupported rule types

| Type | Supported | Basis |
| --- | --- | --- |
| `drug_interaction` | ✅ | Two ingredient conditions across two dispensing lines |
| `duplicate_therapy` | ✅ | Exact same active ingredient on two lines |
| `allergy` | ✅ | Pharmacist-recorded `PatientAllergy` on the same ingredient |
| `age_restriction` | ✅ | `date_of_birth` + minimum/maximum age conditions |
| `pregnancy_caution` | ✅ | Explicit recorded `pregnant` state |
| `lactation_caution` | ✅ | Explicit recorded `lactating` state |
| `contraindication` | ✅ | Ingredient + explicit recorded patient state |
| `renal_caution` | ❌ | No structured renal status exists |
| `hepatic_caution` | ❌ | No structured hepatic status exists |
| `dose_limit` | ❌ | No structured dose/frequency/duration on any line |

Unsupported types remain in the enum as an **architectural extension point**.
They can be saved as drafts but cannot be activated: model validation, the
`RuleLifecycle` service, and the `drug_safety_rules_active_type_supported`
check constraint all refuse it, and the evaluator never dispatches them. No
fake evaluation is performed.

### Documented limitations of the supported types

- **Duplicate therapy** is exact-ingredient only. The repository has no
  therapeutic-class data, so no class-level equivalence is inferred, and text
  similarity is never used.
- **Interactions** are matched across two distinct dispensing lines. A single
  product containing both ingredients is a formulation, not an interaction, and
  is not reported.
- **Patient-dependent rules** (allergy, age, pregnancy, lactation,
  contraindication) require a linked patient. Walk-in POS sales have no patient
  link, so only interaction and duplicate-therapy rules evaluate there.
- **Products without a linked active ingredient** match no rule at all. The
  admin product page states this explicitly.

## Architecture

```
PrescriptionReview
   → DrugSafety::Context      (structured facts only, deterministic digest)
   → DrugSafety::RuleSet      (active rule versions effective at a point in time)
   → DrugSafety::Evaluate     (pure: context + rules → ordered finding drafts)
   → DrugSafety::Reevaluate   (persists one DrugSafetyEvaluation + its findings)
   → DrugSafety::Gate         (read-only dispensing gate)
   → DrugSafety::Acknowledge  (pharmacist acknowledgement / documented override)
```

`Product` and `PrescriptionReview` gained no rule logic; all evaluation lives in
`app/services/drug_safety/`.

| Table | Role |
| --- | --- |
| `active_ingredients` | Stable clinical identity (`code`, `normalized_name`) |
| `product_active_ingredients` | Product ↔ ingredient link with strength/unit |
| `patient_clinical_profiles` | Pharmacist-recorded DOB and pregnancy/lactation state |
| `patient_allergies` | Pharmacist-recorded allergen, keyed on ingredient |
| `drug_safety_rules` | Immutable rule version (`code` + `version`) |
| `drug_safety_rule_conditions` | Typed conditions (ingredient / state / age bound) |
| `drug_safety_evaluations` | One run over one clinical context, sequenced per review |
| `drug_safety_findings` | One rule match, with rule and fact snapshots |
| `drug_safety_acknowledgements` | Append-only pharmacist action record |

## Ingredient identity

Rules match on `active_ingredient_id`, never on product name or free text.
Admins (and inventory managers, who own the catalogue) link products to
ingredients from the admin product page. Ingredients are seeded only from
deterministic local demo data — nothing is imported or scraped.

## Evaluation lifecycle

`DrugSafety::Context` collects, for one review: each non-rejected line's
*candidate product* (`dispensed_product || original_product`) and its sorted
ingredient ids, plus — for online reviews only — the patient's age at the
evaluation date, affirmative recorded states, and active allergen ids. It
performs no external lookup and reads no free text.

The context is hashed (`context_digest`), as is the effective rule set
(`ruleset_digest`). `DrugSafety::Reevaluate` is **idempotent**: if the latest
current evaluation matches both digests, it returns that evaluation and writes
nothing. Otherwise it creates the next sequenced `DrugSafetyEvaluation`, writes
its findings, and marks earlier evaluations superseded.

`DrugSafety::Evaluate` itself is pure — same context and rule versions always
yield the same findings in the same order (severity desc, then dedupe key), with
no duplicates and no side effects.

Re-evaluation is triggered by: review creation, line review start, every line
decision, every substitution, POS cart changes, and any change to the patient's
clinical profile or allergies.

### Superseding and carry-over

- Findings are never deleted. When an evaluation is superseded, its still-`open`
  findings that no longer match become `no_longer_applicable` (system-resolved,
  no actor). Resolved findings keep their historical status.
- A finding's `dedupe_key` encodes the rule code+version, the involved review
  line ids, the involved product ids, and the matched ingredient ids. A
  resolution carries forward to the next evaluation **only** when that key is
  identical — i.e. the pharmacist already answered exactly this clinical
  question about exactly these products. `carried_from_id` records the chain.
- Because a substitution changes the product id, the key changes, so **an old
  acknowledgement can never clear the context a substitution created**.
- "Current" findings are always those of the non-superseded evaluation
  (`DrugSafetyFinding.current`).

The only cascade delete is a *draft* POS line removed before anything was
dispensed: the review item, its findings, and their acknowledgements go with it.
Acknowledgements are otherwise append-only and undeletable.

## Severity and blocking

| Severity | Behaviour |
| --- | --- |
| `info` | Visible only |
| `caution` | Visible; pharmacist awareness expected |
| `major` | Requires acknowledgement (`requires_acknowledgement?`) |
| `critical` | Requires acknowledgement; normally configured as blocking |

`blocking` is a separate per-rule flag and is only permitted for `major`/
`critical` (model validation + `drug_safety_rules_blocking_requires_severity`
check constraint). Severity reflects **local configuration only**; it is not a
clinically validated grading of anything.

Blocking behaviour:

- **Approval / substitution of a line** is refused while an unresolved blocking
  finding involves that line. **Rejection is always allowed** and never requires
  safety clearance.
- **Online review finalisation** (`Prescriptions::FinalizeReview`) is held while
  any blocking finding on the review is unresolved. Resolving the last one
  finalises the review automatically, so the order cannot progress to
  fulfilment on a blocked line.
- **POS completion** (`Pos::Complete`) refuses while any blocking finding is
  unresolved, before any stock, payment, or movement is touched. Completion
  remains idempotent.

## Acknowledgement and override

Only pharmacists (`can_resolve_safety_findings?`) may resolve a finding.
Administrators, order managers, inventory managers, cashiers and customers are
refused server-side, including on direct HTTP requests.

- `acknowledged` — records that the pharmacist read and accepted the alert.
- `overridden` — records a documented decision to proceed despite it.

A reason is mandatory for every override, and for any action on a blocking
finding. Each action writes an append-only `DrugSafetyAcknowledgement`
(`before_update` aborts) and stamps `resolved_by`/`resolved_at` on the finding.
A finding belonging to a superseded evaluation cannot be resolved at all.

## Prescription review integration

The review page shows a review-level banner (evaluation number, timestamp,
blocking summary) and a per-line findings panel. Severity is never colour-only:
each badge carries an Arabic label and a symbol (ⓘ △ ◆ ■), and the blocking
banner uses `role="alert"`.

`Prescriptions::DecideLine` re-evaluates before an approve/substitute decision,
refuses if a blocking finding involves that line, and re-evaluates again after
the decision commits (trigger `substitution_recorded` for substitutions).

## Substitution

A substitution is a new clinical context:

1. The old evaluation is retained and marked superseded; its findings stay
   readable, including any override that was recorded against them.
2. A new evaluation runs against the substitute product.
3. New findings reflect the substitute only. Old clearances cannot carry over
   (different products ⇒ different dedupe key).
4. Dispensing gates read only the current evaluation.

## POS integration

`Pos::Cart` re-evaluates on add/update/remove. The sale page renders the same
banner and panels. Cashiers and order managers running the till can see findings
but cannot clear them — only a pharmacist can. `Pos::Complete` adds the blocking
check alongside its existing prescription/stock validations, so a blocked sale
fails before any batch consumption or payment, and repeated completion with the
same idempotency key still returns the original sale.

Ordinary OTC lines never create a review, never create findings, and are
completely unaffected.

## Online order integration

Findings are evaluated during pharmacist review only. Customers never see rule
mechanics, findings, or clinical wording — customer-facing messaging is
unchanged from Phase 19. Order managers cannot override pharmacist safety
decisions, and fulfilment cannot proceed because the review (and therefore the
order transition) stays open while a blocking finding is unresolved. Mixed
orders keep their Phase 19 behaviour.

## Audit

- Every `DrugSafetyEvaluation` is itself an immutable audit row: sequence,
  trigger, actor (when one exists), timestamp, context and rule-set digests, and
  finding counts.
- Staff-triggered evaluations additionally write `drug_safety_evaluated` to
  `AdminAuditEvent`.
- Acknowledgements and overrides write `drug_safety_finding_acknowledged` /
  `drug_safety_finding_overridden` against the review.
- Rule administration writes `drug_safety_rule_created/updated/activated/
  deactivated/revised`.
- Clinical profile changes write `patient_clinical_profile_recorded` and
  `patient_allergy_recorded/deactivated` with **field names only** — never the
  values. Audit payloads carry stable identifiers, not medical detail.

## Rule administration and versioning

Rule definitions are managed by administrators only
(`can_manage_safety_rules?`). Pharmacists read rule detail from the finding
panel but cannot alter central definitions during a review.

Versioning uses **immutable published versions**: `(code, version)` is unique, a
partial unique index allows only one active version per code, and once a rule is
published only lifecycle columns may change. Editing clinical content means
`RuleLifecycle.revise`, which creates the next version as a draft with copied
conditions; activating it retires the previous active version. Findings
additionally snapshot the rule text, type, severity and blocking flag, so
historical findings never change meaning.

## Reports

`/admin/reports/drug_safety` (admins and pharmacists) shows findings by
severity, by rule type, and by status; open blocking findings; documented
overrides by pharmacist; rule usage frequency; findings created by a
substitution; and evaluation counts. CSV export follows the existing report
infrastructure with Cairo-aware dates and carries **no patient identity and no
matched clinical facts** — only rule/severity/status/workflow columns.

These are operational workload metrics for the pharmacy team. They are not
epidemiological or medical analytics and must not be presented as such.

## Security and privacy

- Clinical routes are staff-only; findings and profiles are unreachable by
  customers, and no clinical detail appears on any public route.
- Resolution is pharmacist-only, enforced server-side in the service, the
  controller, and the model.
- Rule administration is admin-only; catalogue ingredient linkage follows the
  existing catalogue permission.
- Rule text and pharmacist reasons are rendered through normal ERB escaping; a
  regression test asserts that markup in a rule label is escaped, not executed.
- Audit payloads exclude ingredient names, allergens, ages and states.
- No secrets, no external service, no network call is involved in evaluation.

## Demo data

Deterministic and idempotent, with fictional ingredients (`DEMO-ALFA`,
`DEMO-BETA`, `DEMO-GAMMA`, `DEMO-DELTA`) and four fictional rules. Scenarios:

| Order | Demonstrates |
| --- | --- |
| `DEMO-SAFETY-INTERACTION` | Critical blocking interaction, documented override, then approval |
| `DEMO-SAFETY-DUPLICATE` | Duplicate active ingredient, acknowledged warning |
| `DEMO-SAFETY-ALLERGY` | Allergy conflict against a recorded allergen, left open |
| `DEMO-SAFETY-AGE` | Age caution from a recorded date of birth, left open |
| `DEMO-SAFETY-SUBSTITUTION` | Override, then a substitution that retires the interaction and creates a different (allergy) finding |

None of this is real clinical guidance; it exists to exercise the workflow.

## Phase 21 boundary

Out of scope here and deferred: renal/hepatic evaluation (needs structured
clinical input), dose-limit rules (needs structured dose/frequency/duration on
lines), therapeutic-class grouping, POS patient linkage for patient-dependent
rules, ingredient-group allergy matching, and any external drug-information
source. Generative clinical advice, diagnosis, autonomous prescribing, OCR and
prescription NLP remain permanently out of scope.
