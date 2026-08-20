# Per-item prescription review and substitution — Phase 19

Phase 19 upgrades prescription handling from a single decision on the whole
prescription/order to an independent clinical decision on every
prescription-required commercial line, online or in POS. It reuses the Phase
17 batch/FEFO engine and the Phase 18 POS aggregate; it does not add a new
inventory or POS system.

## Architecture decision

A `PrescriptionReview` is a polymorphic aggregate (`reviewable: Prescription |
PosSale`) so the same review, line-lifecycle, and audit code serves online
orders and counter sales. Each prescription-required commercial line
(`OrderItem` or `PosSaleItem`) gets exactly one `PrescriptionReviewItem`,
created lazily by `Prescriptions::EnsureReview` and enforced unique per source
line by a database index. Ordinary lines never get a review item.

`PrescriptionReview`/`PrescriptionReviewItem` carry `lock_version` for
optimistic locking; `PrescriptionDecision` (append-only, `before_update`/
`before_destroy` abort) is the immutable clinical timeline; `TherapeuticSubstitution`
(also append-only) is the permanent original-vs-substitute record. A database
check constraint ties `status` to the presence of `reviewed_by`, `reviewed_at`,
and `dispensed_product_id`, so a terminal decision cannot exist in an
inconsistent shape even from a bypassed application layer.

The pre-Phase-19 whole-prescription `Prescriptions::Review` service still
exists for its `under_review`/`partially_approved` messaging path, but its
`approved`/`rejected` decisions now delegate to the same per-item pipeline
(`line_level_final_decision`) so there is one source of truth. `Pos::ApprovePrescription`
is now a thin compatibility wrapper around `Prescriptions::DecideLine` that also
keeps the legacy `prescription_approved_by`/`_at` columns on `PosSaleItem` in
sync for the existing receipt/report code that reads them.

## Line lifecycle

```
pending → under_review → approved
pending → under_review → substituted
pending → under_review → rejected
```

`Prescriptions::StartLineReview` and `Prescriptions::DecideLine` both accept
`lock_version` and raise/convert `ActiveRecord::StaleObjectError` into a
"reload the page" failure. Both record the actor and timestamp, and both are
blocked once the item is terminal (`terminal_decision_is_immutable` at the
model level, plus a `before_update`/`before_destroy` abort on the decision and
substitution records). Only `pharmacist?` users pass `can_make_prescription_decisions?`;
`admin` retains read/report access via `can_review_prescriptions?` but never
gains clinical authority — this mirrors the explicit split already used for
POS discount approval.

## Approval

Approval keeps the originally prescribed product as the dispensed product,
records the pharmacist and a reason, and — for online orders — creates the
inventory reservation and FEFO-allocates it (reservations for
prescription-required lines are **not** created at order/cart time; only an
approved or substituted line ever holds stock).

## Rejection

A rejected line dispenses nothing, releases or never creates a reservation for
its own line, and does not touch sibling lines. `Prescriptions::FinalizeReview`
recomputes the order/prescription status only from the full set of decided
lines, so a mixed order (ordinary + approved + rejected) settles into
`partially_approved` on the prescription and `submitted` on the order once
every ordinary item or dispensable line exists; an order whose *only* lines
are all rejected settles to `rejected` and its promotion redemptions are
released.

## Therapeutic substitution

`Prescriptions::DecideLine` validates the substitute is present, different
from the original, `active?`, `requires_prescription?`, and `available?`
(FEFO-allocatable, unexpired, unquarantined stock) before accepting a
substitution. On success it:

1. creates the `TherapeuticSubstitution` record (original, substitute,
   pharmacist, reason, timestamp) — permanent, never overwritten;
2. releases any existing reservation for the line if the product changed
   (`Inventory::ReleaseReservation`);
3. creates a new reservation for the substitute and FEFO-allocates it;
4. for POS, calls `Pos::Recalculate`, which prices, discounts, and totals the
   sale from the *effective* (dispensed) product while leaving the original
   commercial line’s product identity untouched.

The original prescribed product is never overwritten — `original_product_id`
is immutable once a decision exists (`terminal_decision_is_immutable`), and
`effective_product`/`effective_unit_price_cents` on `PrescriptionReviewItem`
are the only accessors that resolve to "what is actually dispensed."

## Online-order integration

`Orders::CreateFromCart` no longer reserves or FEFO-allocates
prescription-required lines at checkout; only ordinary lines get an immediate
reservation. `FinalizeReview#finalize_online` is the single place that
recomputes order state once every review item on a prescription has a
terminal decision:

- `prescription_adjustment_cents` (a new `orders` column) carries the sum of
  each line's `line_adjustment_cents` (dispensed total − prescribed total,
  zero for a rejected line). `order.total_cents` is validated as
  `subtotal − discount + delivery_fee − delivery_discount + prescription_adjustment_cents`,
  so a substitution's price difference is reflected without ever rewriting the
  original `OrderItem` snapshot (`unit_price_cents`, `line_total_cents`, etc.
  stay exactly what the customer was quoted at checkout).
- `order.status` becomes `rejected` only if there is no dispensable line at
  all (no ordinary items and every prescription line rejected); otherwise it
  is `submitted`, and `Inventory::ExtendReservations` extends the pending-order
  reservation window for the lines that now hold stock.
- An `order_submitted`-adjacent `prescription_line_review_completed` order
  event (customer-visible, with approved/substituted/rejected counts in
  `metadata`) is appended, in addition to the existing `prescription_approved`/
  `prescription_rejected` event.

## POS integration

`Pos::Cart#update`/`#remove` refuse to touch a line once its review item is
terminal. `Pos::Complete` resolves every line's *effective* product (dispensed
product if the review item is approved/substituted, otherwise the cart
product), skips rejected lines entirely (no pricing, no batch consumption),
and still requires every prescription-required line to be `dispensable?`
before completion — a cashier can never complete a sale with an undecided or
rejected prescription line. FEFO batch consumption, the completion
idempotency key, and the immutability of a completed sale are unchanged from
Phase 18; substitution only changes *which* product's batches are consumed.

## FEFO and reservation integration

Substitution is the only path that moves a line between products after stock
has been touched, so it is intentionally narrow: release the old reservation
(and only its batch allocations — via `Inventory::ReleaseReservation`, which
locks the reservation and each batch before decrementing `reserved_quantity`),
then create-and-allocate a new reservation for the new product. Both the
release and the (re)allocation happen inside `DecideLine`'s single database
transaction, so a `StaleObjectError` or FEFO shortfall rolls back the whole
decision — no orphaned reservation, no partial allocation. Re-running the same
decision on an already-terminal item is rejected before any inventory code
runs, so retries cannot duplicate reservations, allocations, or movements. The
`inventory_reservations` unique index changed from "one row per order item"
to "one row per (order item, status)" so a released-then-reallocated line can
carry its full reservation history without a uniqueness conflict.

## Traceability

`Prescription → PrescriptionReview → PrescriptionReviewItem → original_product
→ PrescriptionDecision (+ TherapeuticSubstitution) → dispensed_product →
InventoryReservation → InventoryReservationAllocation → InventoryBatch → Order
→ customer`. For POS the same chain runs from `PosSale`/`PosSaleItem` through
`PosSaleBatchAllocation`. Every step is a stable foreign key; nothing is
duplicated — the substitution table exists because it is queried directly for
"what got substituted and why" without joining through the full decision
timeline.

## Authorization

| Role | Start/decide a line | View review queue/detail | Reports |
| --- | --- | --- | --- |
| Pharmacist | Yes | Yes | Yes |
| Admin | No (`can_make_prescription_decisions?` is pharmacist-only) | Yes (`can_review_prescriptions?`) | Yes |
| Order manager | No | No (404) | Operational reports only |
| Inventory manager | No | No (404) | Inventory reports only |
| Customer | No | No (404) | No |

All checks are server-side in the controller (`head :not_found`) and the
service (`can_make_prescription_decisions?`), not merely hidden UI. A decision
request is scoped to the specific `PrescriptionReviewItem` looked up under its
own prescription/POS sale, so a forged item ID from another order cannot be
decided through another prescription's page.

## Audit and notifications

`AdminAuditEvent` rows are created for `prescription_line_review_started` and
`prescription_line_{approved,substituted,rejected}`, scoped to the review and
carrying only stable IDs (review item, original/dispensed product) — no
clinical narrative. Customer notifications reuse `Notifications::Create` with
the existing `prescription_approved`/`prescription_rejected` kinds so the
existing in-app/email delivery pipeline is unchanged; Phase 19 adds no new
external channel.

## Reports

`Admin::Reports::PrescriptionsController`/`Reports::PrescriptionPerformance`
now also report, over the selected Cairo-aware range: per-item status counts
(pending/under_review/approved/substituted/rejected), substitution frequency,
and pharmacist workload (decisions per pharmacist). The `prescriptions` CSV
export is now line-item level: order number, line status, prescribed vs.
dispensed product, pharmacist, decision timestamp, reason, and the batch
numbers consumed for a dispensed line — formula-safe and BOM-prefixed like
every other export.

## Demo data

`DemoData::Seeder` drives every terminal prescription-line state through the
real `Prescriptions::EnsureReview`/`StartLineReview`/`DecideLine` services
(not direct attribute writes), so seeded records are indistinguishable from
production data shape:

- `DEMO-PRESCRIPTION-NEW` — pending review.
- `DEMO-PRESCRIPTION-REVIEW` — under_review (`prescription.status` is kept in
  sync with the review by `StartLineReview`/`DecideLine`).
- `DEMO-PRESCRIPTION-APPROVED` — fully approved.
- `DEMO-PRESCRIPTION-REJECTED` — fully rejected.
- `DEMO-PRESCRIPTION-SUBSTITUTED` — therapeutic substitution.
- `DEMO-PRESCRIPTION-MIXED` — one ordinary line, one approved prescription
  line, one rejected prescription line, in a single order.
- `DEMO-POS-RX-SUBSTITUTED` — a completed POS sale with a substituted line.

Seeding suppresses transactional email enqueueing for the duration of the run
(`Thread.current[:suppress_transactional_email]`, checked in
`EmailDeliveries::Enqueue`) so exercising the real decision pipeline for demo
data never queues or sends mail; this flag is only ever set by the seeder, so
real requests are unaffected. Every scenario is idempotent on a second run.

## Phase 20 safety engine integration

Phase 20 layers decision support on this workflow without changing its state
machine. `EnsureReview`, `StartLineReview` and `DecideLine` each re-run
`DrugSafety::Reevaluate`; `DecideLine` refuses an approve/substitute decision
while an unresolved blocking finding involves that line (rejection is always
allowed and never needs safety clearance), re-evaluates again after the decision
commits, and `FinalizeReview` waits until the safety gate is clear. A
substitution is treated as a new clinical context: the previous evaluation is
retained and superseded, the substitute is evaluated in its own right, and an
acknowledgement recorded against the old context cannot clear the new one.
See [`docs/drug_safety_rules.md`](drug_safety_rules.md).

## Phase 21 substitution lookup

Phase 21 replaced the full `<select>` of every allocatable prescription product with a
pharmacist-only search panel (`Staff::SubstitutionCandidatesController`) that renders radio
options inside the existing decision form. Search filters for an active, prescription-required
product with an allocatable batch, and finds candidates by name, SKU, barcode or structured
active ingredient. It deliberately makes no therapeutic claim: the panel states so in the UI,
the results are unordered with respect to clinical suitability, and selection still flows
through `DecideLine` with its Phase 19 guards and Phase 20 re-evaluation intact.

## Limitations

Phase 19 itself is human pharmacist line-level review and documented
substitution only. Interaction, allergy, contraindication, duplicate-therapy,
age and pregnancy/lactation checking arrived in Phase 20 as configured local
rules; renal/hepatic and dose-limit rules remain unsupported because the
required structured data does not exist. A clinical knowledge base, AI
recommendations, OCR prescription interpretation and physician messaging remain
out of scope. The whole-prescription `Prescriptions::Review#review` action remains
reachable (e.g. for a future bulk-reopen path) but the application UI only
exercises the per-item flow; treat the whole-prescription path as a
compatibility surface, not the primary API.
