# Technical reviewer guide

For Phase 18, sign in as the order manager, pharmacist or admin and open
`/pos`. Open a session, scan a demo barcode, complete a cash sale, inspect the
receipt and close the session. Use the pharmacist for a prescription-required
line and the admin for a manual discount. Reports are at `/admin/reports/pos`.
See [pos.md](pos.md).

This guide provides a high-signal technical path through the repository. Start
with the [reviewer and presentation index](deliverables_index.md) if you need a
different audience path; otherwise use the sequence below rather than reading
every controller or migration.

For a visual orientation before reading code, open the
[real-application gallery](visual_gallery.md). Its captions identify the role,
stable fictional scenario, and business behavior behind each capture.

## 1. Architecture and scope

- [`docs/architecture.md`](architecture.md) explains the deployed boundaries,
  domains, transactions, security model, and limitations.
- [`docs/feature_matrix.md`](feature_matrix.md) separates implemented, demo-ready,
  partial/external, and planned capabilities.
- [`config/routes.rb`](../config/routes.rb) shows the customer, staff, admin,
  report, export, health, and private-file HTTP boundaries.

Look for: one Rails modular monolith, explicit roles, private resources, and a
roadmap that is not presented as current functionality.

## 2. Checkout and commercial snapshots

- [`app/services/orders/create_from_cart.rb`](../app/services/orders/create_from_cart.rb)
  is the primary transaction. It validates address/delivery/payment, locks
  mutable inputs, recalculates totals, and creates snapshots, reservations,
  fulfilment, promotion records, and a prescription when required.
- [`app/models/order.rb`](../app/models/order.rb) defines states and verifies
  total arithmetic.
- [`app/models/order_item.rb`](../app/models/order_item.rb) demonstrates the
  immutable product and price fields retained at submission.

Look for: the checkout submission token, deterministic row locking, one
transaction, explicit cash-on-delivery policy, and no recomputation of history
from current catalog data.

## 3. Inventory reservation and movement

- [`app/services/inventory/consume_reservations.rb`](../app/services/inventory/consume_reservations.rb)
  turns active reservations into physical stock changes and movements.
- [`app/services/inventory/release_reservations.rb`](../app/services/inventory/release_reservations.rb)
  releases unconsumed commitments without inventing stock.
- [`app/services/inventory/adjust_stock.rb`](../app/services/inventory/adjust_stock.rb)
  protects manual adjustments with authorization, locking, and reservation
  floors.
- [`app/models/inventory_movement.rb`](../app/models/inventory_movement.rb) is an
  append-only arithmetic ledger record.

Look for: physical versus reserved versus available quantities, idempotency
keys, update/delete prevention, and transactional locking.

## 4. Prescription workflow and file boundary

- [`docs/prescription_review.md`](prescription_review.md) documents the
  per-item review architecture end to end.
- [`app/services/prescriptions/decide_line.rb`](../app/services/prescriptions/decide_line.rb),
  [`start_line_review.rb`](../app/services/prescriptions/start_line_review.rb), and
  [`ensure_review.rb`](../app/services/prescriptions/ensure_review.rb) own the
  per-line pharmacist decision, its inventory/FEFO consequences, and
  therapeutic substitution.
- [`app/services/prescriptions/finalize_review.rb`](../app/services/prescriptions/finalize_review.rb)
  settles the order/prescription once every line has a terminal decision, and
  holds off while an unresolved blocking safety finding exists.
- [`docs/drug_safety_rules.md`](drug_safety_rules.md) and
  [`app/services/drug_safety/`](../app/services/drug_safety) own the Phase 20
  decision-support engine: `context.rb` (structured facts only),
  `evaluate.rb` (pure, deterministic, no side effects), `reevaluate.rb`
  (idempotent persistence and superseding), `gate.rb` (dispensing gate) and
  `acknowledge.rb` (pharmacist-only resolution).

Look for: the safety boundary (no prescribing, diagnosis, auto-substitution or
AI), rules as data rather than code, immutable rule versions plus per-finding
snapshots, and the fact that a substitution's new context can never be cleared
by an acknowledgement recorded against the old one.

- [`app/services/prescriptions/review.rb`](../app/services/prescriptions/review.rb)
  is the earlier whole-prescription entry point, now a compatibility surface
  that delegates terminal decisions to the per-line pipeline.
- [`app/services/prescriptions/attachment_validator.rb`](../app/services/prescriptions/attachment_validator.rb)
  validates proposed uploads before checkout.
- [`app/services/uploads/file_signature.rb`](../app/services/uploads/file_signature.rb)
  performs bounded signature checks.
- [`app/services/uploads/scanner.rb`](../app/services/uploads/scanner.rb) defines
  deterministic/test and ClamAV adapters, timeouts, and safe results.
- [`app/controllers/prescription_files_controller.rb`](../app/controllers/prescription_files_controller.rb)
  demonstrates authorized private download behavior.

Look for: scan-state gating, no public storage key, role/ownership enforcement,
and release behavior after rejection.

## 5. Product search

- [`docs/search.md`](search.md) documents the normalization policy, ranking tiers,
  index strategy and measured query plans.
- [`app/services/search/arabic_normalizer.rb`](../app/services/search/arabic_normalizer.rb)
  is a pure, unit-tested folding table; note that it is used for matching only and never
  rewrites stored display text.
- [`app/services/search/products.rb`](../app/services/search/products.rb) builds one
  parameterized query. Every value is bound; the single ORDER BY literal is composed by
  `sanitize_sql_array` and covered by
  [`test/services/search/injection_safety_test.rb`](../test/services/search/injection_safety_test.rb).

Look for: exact barcode and SKU pinned above every fuzzy match, `EXISTS` instead of joins so
no product is duplicated, the substitution context requiring an allocatable batch, and the
fact that search surfaces products without ever asserting therapeutic equivalence — the
Phase 19 decision and Phase 20 re-evaluation still run after a pharmacist selects one.


## 6. Order and fulfilment transitions

- [`app/services/orders/transition.rb`](../app/services/orders/transition.rb)
  lists allowed order edges and couples ready/cancelled states to inventory.
- [`app/services/orders/cancel.rb`](../app/services/orders/cancel.rb) distinguishes
  customer, staff, and system cancellation.
- [`app/services/delivery/update_fulfilment.rb`](../app/services/delivery/update_fulfilment.rb)
  governs picking, packing, dispatch, and delivery updates.

Look for: explicit transition maps, authorization within services, optimistic
locking, repeat safety, and order events/notifications.

## 7. Pricing, promotions, and delivery

- [`app/services/promotions/calculator.rb`](../app/services/promotions/calculator.rb)
  provides deterministic line/cart/delivery discount calculation.
- [`app/services/promotions/eligibility.rb`](../app/services/promotions/eligibility.rb)
  applies schedule, scope, minimum, exclusion, and usage rules.
- [`app/services/delivery/zone_matcher.rb`](../app/services/delivery/zone_matcher.rb)
  resolves active geographic delivery configuration from an address.

Look for: integer-cent arithmetic at order boundaries, calculation-version and
promotion snapshots, database locks at checkout, and bounded delivery capacity.

## 8. Authentication and authorization

- [`app/models/user.rb`](../app/models/user.rb) shows roles, capabilities,
  encrypted TOTP, recovery-code consumption, and session-version triggers.
- [`app/controllers/application_controller.rb`](../app/controllers/application_controller.rb)
  applies active-account, stale-session, privileged-2FA, and maintenance checks.
- [`app/controllers/admin/base_controller.rb`](../app/controllers/admin/base_controller.rb)
  and [`app/controllers/staff/base_controller.rb`](../app/controllers/staff/base_controller.rb)
  establish privileged controller boundaries.

Then inspect [`test/controllers/phase14_security_test.rb`](../test/controllers/phase14_security_test.rb)
and [`test/controllers/phase8_requests_test.rb`](../test/controllers/phase8_requests_test.rb)
for cross-role and ownership regression coverage.

## 9. Reports and background delivery

- [`app/services/reports/async_exporter.rb`](../app/services/reports/async_exporter.rb)
  captures safe filters, authorization, deduplication, and active-export limits.
- [`app/jobs/reports/generate_export_job.rb`](../app/jobs/reports/generate_export_job.rb)
  revalidates authorization and creates the private CSV attachment.
- [`app/jobs/transactional_email_delivery_job.rb`](../app/jobs/transactional_email_delivery_job.rb)
  records attempts and sanitized failures without storing message bodies.
- [`config/recurring.yml`](../config/recurring.yml) is the production recurring
  job registry.

Look for: ownership revalidation at execution/download, formula-safe CSV,
retention cleanup, job heartbeats, and business transactions independent of mail
delivery success.

## 10. Demo architecture

- [`app/services/demo_data/seeder.rb`](../app/services/demo_data/seeder.rb)
  creates the deterministic fictional graph and protects execution boundaries.
- [`app/services/demo_data/manifest.rb`](../app/services/demo_data/manifest.rb)
  exposes testable seed results.
- [`app/services/demo_guidance/journey_catalog.rb`](../app/services/demo_guidance/journey_catalog.rb)
  describes role journeys.
- [`app/services/demo_guidance/scenario_resolver.rb`](../app/services/demo_guidance/scenario_resolver.rb)
  resolves stable identifiers under current capabilities.
- [`test/services/demo_data_seeder_test.rb`](../test/services/demo_data_seeder_test.rb)
  and [`test/controllers/guided_demo_test.rb`](../test/controllers/guided_demo_test.rb)
  verify repeatability, safety, stable links, and authorization.

Look for: no primary-key manifest, no normal-authentication bypass, suppressed
external work during seeding, and explicit refusal outside safe demo settings.

## 11. Build and operational evidence

- [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) runs tests, audits,
  assets, framework loading, and Docker verification.
- [`Dockerfile`](../Dockerfile) is a multi-stage non-root production image.
- [`config/initializers/production_configuration.rb`](../config/initializers/production_configuration.rb)
  fails safely on missing required production configuration.
- [`app/services/operations/integrity_check.rb`](../app/services/operations/integrity_check.rb)
  detects cross-domain inconsistencies without automatic repair.

The repository contains operational preparation, not evidence that a permanent
public deployment or external scanner/SMTP/storage provider is currently active.

## 12. Suppliers, purchasing, and receiving

- [`docs/purchasing.md`](purchasing.md) defines roles, states, receiving
  invariants, reporting, and the Phase 17 boundary.
- [`app/services/purchasing/receive.rb`](../app/services/purchasing/receive.rb)
  is the stock-changing transaction.
- [`app/models/purchase_receipt.rb`](../app/models/purchase_receipt.rb) and
  [`app/models/purchase_receipt_item.rb`](../app/models/purchase_receipt_item.rb)
  preserve immutable partial-delivery events.
- [`app/services/reports/purchasing_summary.rb`](../app/services/reports/purchasing_summary.rb)
  reads purchasing activity and received cost history.

Look for: admin-only approval, frozen submitted lines, deterministic locks,
outstanding-quantity validation, receipt idempotency, batch-linked inventory
movements, and no selling-price side effect.

## Phase 17 batch review

Inventory managers and administrators can open **التشغيلات والصلاحية** to inspect
batch provenance, expiry, quarantine, movements, reservations, orders, and
customers. The batch report demonstrates FEFO-ready availability and
received-cost valuation. The deterministic demo includes expired, near-expiry,
and quarantined examples.

For Phase 22, open **المرتجعات** from staff navigation, locate a delivered order or completed POS receipt, approve it, inspect prescription lines as the pharmacist, receive to the original batch, then post the refund as admin. Retry receipt/refund to observe idempotency and verify the original transaction remains unchanged.
