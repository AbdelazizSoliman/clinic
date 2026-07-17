# Phase 14 production readiness

Rails is upgraded from 7.2.3.1 to 8.1.3; Ruby remains 3.4.6. Rails 8.1 defaults
are loaded deliberately. PostgreSQL, Devise, Importmap, Turbo, Stimulus,
Tailwind, Pagy, Active Storage, and Active Job remain in place. Production uses
private S3-compatible storage, SMTP, Solid Queue, and Solid Cache. Boot fails
with variable names—not values—when required production configuration is absent.

## Deployment checklist

- Review dependency audits, Brakeman, tests, CSP reports, and migrations.
- Configure environment variables and Active Record encryption keys.
- Configure private bucket encryption/versioning/CORS (direct uploads are off).
- Configure SMTP domain authentication and sender; send a non-medical test.
- Configure real malware scanner before accepting production prescriptions.
- Verify backups by restoration, then run pre-deploy `db:prepare`.
- Verify `/up`, `/health/ready`, privileged 2FA, storefront, checkout, worker
  heartbeat, mail, private attachments, headers, RTL/mobile, and error pages.

## Privacy and retention

Prescription data is sensitive, access is role-scoped, storage is intended to
be private, and audit/security events exist. Prescription and delivery-proof
retention, notifications, audit/security events, invitations, inactive carts,
and failed-job retention require approved business/legal decisions. Report
exports should expire after seven days when asynchronous exports are enabled.
Do not automatically delete medical history without approval. The production
operator must confirm Egyptian and every operating-market privacy, pharmacy,
e-commerce, and medical-data requirements. Technical controls alone do not
establish legal compliance.

## External deployment gates

The scanner boundary, asynchronous exports, delivery tracking, operations
dashboard, and static Arabic error pages are implemented. They do not prove that
external infrastructure is operating. Before any real launch, independently
verify a real private bucket, SMTP account, ClamAV service, shared database-backed
queue/cache, backups and restore, monitoring, domain/TLS, and production-shaped
performance. A configured adapter is not evidence that the provider works.

## Local verification limits

The existing `test:system` task contains zero committed system tests. No
Chrome/Chromium executable is installed in the current local environment, so a
local real-browser desktop/390px, keyboard, overflow, and end-to-end TOTP QR run
has not been completed. GitHub Actions installs Chrome for the system-test task.
The production Docker image, non-root runtime, eager load, assets, and container
health check have been verified in GitHub Actions; external services were not
contacted by that verification.

Database-backed services retain existing locking/idempotency protections for
checkout reservations, promotion redemptions, delivery-slot counters, and the
final-admin guard. Continuation tests verify repeated export requests, email
delivery/retry state, scanner classification, and recurring cleanup safety. These
are correctness tests, not production load or throughput claims; run contention
tests against production-shaped PostgreSQL before launch.

## Continuation architecture

Large report requests use `ReportExport`, Solid Queue, private Active Storage,
application-authorized downloads, three active exports per user, deduplication,
and seven-day expiry. Important notification emails use persistent
`TransactionalEmailDelivery` records with sanitized failure classes and
admin-authorized retry. `/admin/security` summarizes 2FA gaps, locked accounts,
security events, delivery/export/scan failures, heartbeats, configuration, and
bounded integrity findings. Error reporting is provider-neutral and structured
JSON logging is production-only; local logs remain human-readable.
