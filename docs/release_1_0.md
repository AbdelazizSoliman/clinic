# Release 1.0

Release 1.0 certifies the repository state at baseline commit
`67b7947c3fbf29c8c4964929582efccbe4294dd3` on `main`. It packages the merged
Phase 27 system as an Arabic RTL pharmacy portfolio application with
application-level organization tenancy and multi-branch operations. It is a
repository and isolated-demo certification, not
a claim of a live production deployment or regulatory approval.

This evidence is historical and commit-scoped. It must not be presented as
verification of later commits or an uncommitted working tree. In current
buyer-facing wording, tenancy means application-level organization isolation and
multi-branch operations; Release 1.0 does not include a commercial
SaaS control plane, platform-super-admin provisioning, subscription billing, or
plan enforcement.

## Scope

- Customer storefront, Arabic search, cart, promotions, checkout, orders and
  fulfilment.
- Per-item prescription review, therapeutic substitution, and deterministic
  locally configured drug-safety findings and dispensing gates.
- Branch-local batch/lot inventory, expiry/quarantine controls, FEFO,
  purchasing/receiving, transfers, POS, returns and reverse logistics.
- Immutable loyalty-point and monetary-wallet ledgers, refunds, and POS cash
  reconciliation.
- Organization tenancy, branch staff access, scoped API credentials,
  idempotent safe API writes, signed webhook delivery, and analytics/CSV.
- Deterministic fictional demo data and role-aware guided journeys.

## Architecture and invariants

The application is a Rails modular monolith backed by PostgreSQL. The ownership
hierarchy is Platform → Organization → Branch → operational records. Domain
services own multi-record transitions under transactions and locks. Important
invariants include tenant-scoped record loading, branch-local allocation,
`InventoryBatch` as physical-stock authority, append-only/idempotent movements,
immutable commercial and clinical history, ledger-derived balances, and
digested integration credentials.

See [architecture.md](architecture.md), [feature_matrix.md](feature_matrix.md),
and [reviewer_guide.md](reviewer_guide.md).

## Certification evidence — 2026-08-27

- Runtime: Ruby 3.4.6, Rails 8.1.3.1, PostgreSQL 16.15, Bundler 4.0.9,
  Brakeman 8.0.6, RuboCop 1.88.2, `tailwindcss-rails` 4.6.0 / Tailwind 4.3.2.
- Populated database: fully migrated through `20260822170000`; selected
  organization/branch/user/batch/movement/order counts were unchanged by
  `db:migrate`.
- Clean database: all 43 migrations applied from zero; newest migration safely
  rolled back and reapplied in the disposable database. Test schema prepared.
  Full historical rollback is not claimed.
- Tests: 411 runs, 2,346 assertions, 0 failures, 0 errors, 0 skips.
- Quality/security: RuboCop 534 files/0 offenses; Zeitwerk and Tailwind build
  passed; Brakeman 0 warnings with one pre-existing documented SQL-ordering
  ignore; bundler-audit and importmap audit found no known vulnerabilities.
- Read-only tasks: tenant, inventory, and financial integrity all returned
  `OK` against the development/demo database.
- Focused isolation/domain suite: 179 tests passed for tenant IDOR/service
  boundaries, branches/transfers, inventory, ledgers/returns, clinical safety,
  search, POS, purchasing, APIs, webhook URL safety, analytics, and jobs.
- Deterministic demo: two consecutive clean-isolated passes returned identical
  manifests and economic totals (`476` batch on hand, `476` movement delta,
  `1426` loyalty points, `26000` wallet cents), with 2 organizations, 4
  branches, 0 queued webhook deliveries and 0 email deliveries. The audit fixed
  clean-database seeding so the primary organization is established before
  tenant-required accounts.

Browser screenshots in the existing gallery predate Release 1.0 and are not
Release 1.0 certification evidence. No usable Chrome/Chromium executable was
available in the audit environment, so current real-browser recapture remains
open and no browser or accessibility conformance claim is made.

## External configuration

Production operation requires owner-provided secrets and infrastructure for
PostgreSQL, private object storage, SMTP, malware scanning/ClamAV, TLS/host
configuration, monitoring/error reporting, backups/restores, scheduled workers,
and API/webhook consumers. Network webhook delivery was not performed during
certification. Payment gateways, external terminals, courier/SMS/WhatsApp
providers, and external clinical knowledge sources are not integrated.

## Background-job audit

`LaunchSmokeJob` is platform-global and carries no tenant data. Reservation and
invitation expiry plus export cleanup are platform fan-out coordinators that
enqueue one explicit organization ID per active tenant. Prescription scanning,
email/invitation delivery, report generation and webhook delivery are tenant
sensitive: each serializes `organization_id`, enters
`ApplicationJob#with_organization`, performs scoped lookup, and clears `Current`
in an ensure block. Report generation restores a scoped branch from the saved
filter. Retry/idempotency guards use delivery state, deduplication keys,
completed/expired status, and webhook delivery identity. Invitation job
arguments are excluded from logging because the one-time token reaches the
mailer. Focused tenant-context job tests pass.

## Known limitations

- No permanent hosted demo or verified real-production operation.
- No platform-super-admin provisioning, self-service tenant onboarding,
  subscription billing, plan enforcement, or production tenant validation.
- No formal accessibility, penetration-test, performance-capacity, medical,
  legal, privacy, PCI, HIPAA, or GDPR certification.
- Drug-safety output is deterministic decision support based only on locally
  configured rules and structured data; it does not prescribe or diagnose.
- External terminal refunds are recorded as operational markers, not executed
  against a payment provider.
- A repository license has not been selected; owner decision is required.
- The general `db/seeds.rb` starter catalog contains real brand names and
  health-oriented copy; it requires a separate fictionalization/licensing pass
  before commercial distribution. The isolated `demo:seed` dataset is separate.
