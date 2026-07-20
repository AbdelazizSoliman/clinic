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
- **Roadmap:** named as future work, with no delivery commitment.

## Can this support multiple pharmacies or tenants?

**Current status: not implemented; roadmap.** The application has one globally
scoped pharmacy. Supporting independent pharmacies requires tenant ownership on
business records, strict query and job isolation, tenant-aware storage and
cache keys, configuration, authorization, administration, billing decisions,
data migration, and isolation tests. It should be treated as a SaaS-tenancy
project, not a configuration switch.

## Can it support multiple branches of one pharmacy?

**Current status: not implemented; roadmap.** Branches require branch-specific
stock and reservations, staff assignments, catalogs/prices where applicable,
delivery coverage, fulfilment routing, transfers, reports, settings, and access
rules. The present inventory dashboard and order flow are global.

## Can it support online payment?

**Current status: cash on delivery implemented; gateway not implemented.** A
payment extension would need a selected provider and market, payment intent and
webhook handling, signature verification, idempotency, asynchronous success and
failure states, refunds/cancellations, reconciliation, fraud/PCI boundaries,
and tests. No online-payment claim should be made today.

## Can suppliers and purchasing be added?

**Current status: not implemented; roadmap.** Supplier records, purchase orders,
approval, receiving, cost history, discrepancies, and accounts/ERP boundaries
can be designed as an extension. They should be coordinated with lot/expiry
requirements because receiving often creates batch-level stock.

## Does it track batches, lots, expiry, or FEFO?

**Current status: not implemented; roadmap.** Inventory is product-level.
Batch-level receiving, expiry dates, quarantine/recall, allocation, FEFO,
adjustments, and traceability require a deeper inventory model and migration.

## Can loyalty points or a wallet be added?

**Current status: not implemented; roadmap.** A safe extension would require an
append-only points/credit ledger, earning and redemption rules, expiry,
reversal, promotion interaction, abuse controls, and financial/accounting
decisions. Existing promotions and coupons are not a loyalty wallet.

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
and security. Public/partner APIs are themselves roadmap work.

## Is prescription upload and review already implemented?

**Current status: implemented/demo-ready, with an external scanner boundary.**
Required-product upload, validation, private authorized access, scan states,
pharmacist review, follow-up, and order/reservation consequences exist. A real
ClamAV service must be configured and verified. This is workflow and file
security, not automated medical validation.

## Does it check drug interactions, allergies, or substitutions?

**Current status: not implemented; roadmap.** There is no drug-safety engine,
clinical decision support, or per-item substitution workflow. Such work requires
licensed clinical input, authoritative data sources, jurisdictional review,
versioning, overrides, audit, and extensive safety validation.

## Are promotions and coupons implemented?

**Current status: implemented/demo-ready.** The portfolio includes product,
category, brand, cart, and delivery scopes; compatible percentage, fixed,
fixed-price, and free-delivery calculations; schedules, minimums, exclusions,
limits, priority/stacking policy, redemption and release, and snapshots.
Client-specific commercial rules still require confirmation.

## Are reports and exports implemented?

**Current status: implemented/demo-ready.** Role-scoped operational reports and
formula-safe CSV are present. Private queued exports include ownership checks,
deduplication, limits, status, and expiry. This is operational reporting, not
the roadmap's advanced analytics module.

## Is email implemented?

**Current status: partial/external.** The application has environment SMTP
configuration and durable delivery/retry tracking. A real sender/domain,
provider, templates, reputation controls, privacy policy, and monitoring must be
configured and verified for a live environment.

## Is the application ready to deploy publicly?

**Current status: no public deployment.** CI, Docker verification, production
configuration validation, health/readiness endpoints, and operational runbooks
are present. A real launch still requires infrastructure, providers, secrets,
backups, monitoring, domain/TLS, capacity testing, data preparation, support
ownership, and legal/security/accessibility review.

## Can it expose mobile or partner APIs?

**Current status: not implemented; roadmap.** The application is server-rendered
with Hotwire. API work requires consumers, versioning, authentication and
authorization, rate limits, serialization, idempotency, documentation, and
support commitments. Responsive browser views are not an API.

## Is it compliant with HIPAA, GDPR, PCI, or pharmacy regulations?

**Current status: no certification or compliance claim.** Technical safeguards
such as role scoping, private files, TOTP, headers, filtering, events, and
fail-closed scanning reduce risk. Compliance depends on jurisdiction,
contracts, infrastructure, policies, people, audits, and qualified legal,
medical, privacy, and security review.

## Can it be demonstrated now?

**Current status: demo-ready on request.** A temporary isolated environment can
be seeded with deterministic fictional data and shown through normal customer
and privileged authentication. There is no permanent public URL or published
credential. Access is revoked and secrets are rotated after the session.
