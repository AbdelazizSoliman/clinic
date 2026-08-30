# Client capability FAQ

This document distinguishes the current portfolio from possible extensions.
“Possible” means technically discussable after discovery, not included,
estimated, certified, or promised. The [feature matrix](feature_matrix.md) is
the canonical implementation-status reference.

## Status key

- **Implemented:** present in the current repository.
- **Partial/external:** an application boundary exists, but a real service must
  be selected, configured, and operationally verified.
- **Possible extension:** not implemented; requires discovery and engineering.
- **Intentionally absent:** outside the Release 1.0 boundary unless separately
  discovered, implemented, and validated.

## Can this support multiple pharmacies or tenants?

**Current status: implemented/demo-ready.** Organizations own business records,
credentials, configuration, jobs and reporting. Direct-ID and service-level
isolation tests cover representative domains. Subscription billing and a
platform-super-admin provisioning workflow, self-service tenant onboarding, plan
enforcement, and production tenant validation are not part of Release 1.0.

## Can it support multiple branches of one pharmacy?

**Current status: implemented/demo-ready.** Staff memberships and branch
switching constrain branch-local batches, FEFO, reservations, POS, purchasing,
fulfilment, transfers, returns and reports. Catalog data remains tenant-wide.

## Can it support online payment?

**Current status: cash on delivery implemented; gateway not implemented.** A
payment extension would need a selected provider and market, payment intent and
webhook handling, signature verification, idempotency, asynchronous success and
failure states, refunds/cancellations, reconciliation, fraud/PCI boundaries,
and tests. No online-payment claim should be made today.

## Can suppliers and purchasing be added?

**Current status: implemented/demo-ready.** Supplier records, purchase orders,
submission/approval, partial and final receipt, batch creation, cost history and
purchasing reports are present. Supplier invoicing/payment and ERP exchange are
not implemented. There is no supplier-return workflow; customer/POS sales
returns are a separate implemented domain.

## Does it track batches, lots, expiry, or FEFO?

**Current status: implemented/demo-ready.** `InventoryBatch` is authoritative;
receipts create branch-local lots with expiry/cost, FEFO excludes expired or
quarantined stock, and allocations/movements retain batch provenance.

## Can loyalty points or a wallet be added?

**Current status: implemented/demo-ready.** Separate immutable loyalty and
monetary-wallet ledgers support earning, redemption, expiry and bounded return
reversals across online and identified POS transactions.

## Can WhatsApp be integrated?

**Current status: not implemented; possible external integration.** A project
would need an approved provider/account, customer consent, template rules,
locale/content ownership, delivery status/webhooks, retries, opt-out handling,
privacy/retention decisions, and operational monitoring. Current notifications
and email boundaries do not imply WhatsApp support.

## Can SMS be integrated?

**Current status: not implemented; possible external integration.** Provider,
sender registration, consent, templates, retry/idempotency, delivery receipts,
cost controls, and privacy rules must be scoped. There is no current SMS adapter.

## Can a courier or delivery provider be integrated?

**Current status: internal delivery workflow implemented; provider integration
not implemented.** Current zones, methods, slots, fees, fulfilment, dispatch,
and delivery states are internal. A courier project would add quoting/booking,
address mapping, webhooks, cancellation, tracking, reconciliation, failure
handling, and manual fallback.

## Can it integrate with an ERP?

**Current status: not implemented; possible extension.** Discovery must define
the system of record, data ownership, identifiers, synchronization direction,
API/file protocol, mapping, retries, reconciliation, conflict handling, audit,
and security. Versioned scoped APIs and signed webhooks provide a safe
integration boundary, but no ERP-specific mapping is included.

## Is prescription upload and review already implemented?

**Current status: implemented/demo-ready, with an external scanner boundary.**
Required-product upload, validation, private authorized access, scan states,
pharmacist review, follow-up, and order/reservation consequences exist. A real
ClamAV service must be configured and verified. This is workflow and file
security, not automated medical validation.

## Does it check drug interactions, allergies, or substitutions?

**Current status: implemented/demo-ready with a strict boundary.** Pharmacists
can approve, reject or substitute each prescription line. A deterministic,
versioned local rules engine re-evaluates structured context and blocks unresolved
findings. It uses no external clinical database and does not diagnose or prescribe.
Pharmacist acknowledgement and documented override remain human decisions; the
engine does not replace pharmacist judgment.

## Are promotions and coupons implemented?

**Current status: implemented/demo-ready.** The portfolio includes product,
category, brand, cart, and delivery scopes; compatible percentage, fixed,
fixed-price, and free-delivery calculations; schedules, minimums, exclusions,
limits, priority/stacking policy, redemption and release, and snapshots.
Client-specific commercial rules still require confirmation.

## Are reports and exports implemented?

**Current status: implemented/demo-ready.** Role-scoped operational reports and
formula-safe CSV are present. Private queued exports include ownership checks,
deduplication, limits, status, and expiry. Release 1.0 also includes
tenant/branch-aware executive and operational analytics with comparisons.

## Is email implemented?

**Current status: partial/external.** The application has environment SMTP
configuration and durable delivery/retry tracking. A real sender/domain,
provider, templates, reputation controls, privacy policy, and monitoring must be
configured and verified for a live environment.

## Is the application ready to deploy publicly?

**Current status: no permanent validated public deployment.** CI configuration,
commit-scoped Docker verification, production
configuration validation, health/readiness endpoints, and operational runbooks
are present. A real launch still requires infrastructure, providers, secrets,
backups, monitoring, domain/TLS, capacity testing, data preparation, support
ownership, browser/system verification, and legal/security/accessibility review.

## Can it expose mobile or partner APIs?

**Current status: implemented integration API.** Versioned endpoints use
display-once/digested scoped credentials, tenant isolation, rate limits and
idempotency for supported writes. The actual surface covers catalog, branch,
inventory and order reads, order cancellation, purchasing/return reads, and
webhook management. This is not a generic full API, native mobile application,
or promise of compatibility with an unspecified partner.

## Is it compliant with HIPAA, GDPR, PCI, or pharmacy regulations?

**Current status: no certification or compliance claim.** Technical safeguards
such as role scoping, private files, TOTP, headers, filtering, events, and
fail-closed scanning reduce risk. Compliance depends on jurisdiction,
contracts, infrastructure, policies, people, audits, and qualified legal,
medical, privacy, and security review.

## Can it be demonstrated now?

**Current status: repository/demo-data ready for an on-request walkthrough.** A temporary isolated environment can
be seeded with deterministic fictional data and shown through normal customer
and privileged authentication. There is no permanent public URL or published
credential, and zero browser/system scenarios are committed at the current
baseline. Access is revoked and secrets are rotated after the session.
