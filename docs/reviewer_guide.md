# Technical reviewer guide

This guide provides a high-signal path through the repository. Start with the
[README](../README.md), then use the sequence below rather than reading every
controller or migration.

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

- [`app/services/prescriptions/review.rb`](../app/services/prescriptions/review.rb)
  owns pharmacist decisions and their order/reservation consequences.
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

## 5. Order and fulfilment transitions

- [`app/services/orders/transition.rb`](../app/services/orders/transition.rb)
  lists allowed order edges and couples ready/cancelled states to inventory.
- [`app/services/orders/cancel.rb`](../app/services/orders/cancel.rb) distinguishes
  customer, staff, and system cancellation.
- [`app/services/delivery/update_fulfilment.rb`](../app/services/delivery/update_fulfilment.rb)
  governs picking, packing, dispatch, and delivery updates.

Look for: explicit transition maps, authorization within services, optimistic
locking, repeat safety, and order events/notifications.

## 6. Pricing, promotions, and delivery

- [`app/services/promotions/calculator.rb`](../app/services/promotions/calculator.rb)
  provides deterministic line/cart/delivery discount calculation.
- [`app/services/promotions/eligibility.rb`](../app/services/promotions/eligibility.rb)
  applies schedule, scope, minimum, exclusion, and usage rules.
- [`app/services/delivery/zone_matcher.rb`](../app/services/delivery/zone_matcher.rb)
  resolves active geographic delivery configuration from an address.

Look for: integer-cent arithmetic at order boundaries, calculation-version and
promotion snapshots, database locks at checkout, and bounded delivery capacity.

## 7. Authentication and authorization

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

## 8. Reports and background delivery

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

## 9. Demo architecture

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

## 10. Build and operational evidence

- [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) runs tests, audits,
  assets, framework loading, and Docker verification.
- [`Dockerfile`](../Dockerfile) is a multi-stage non-root production image.
- [`config/initializers/production_configuration.rb`](../config/initializers/production_configuration.rb)
  fails safely on missing required production configuration.
- [`app/services/operations/integrity_check.rb`](../app/services/operations/integrity_check.rb)
  detects cross-domain inconsistencies without automatic repair.

The repository contains operational preparation, not evidence that a permanent
public deployment or external scanner/SMTP/storage provider is currently active.
