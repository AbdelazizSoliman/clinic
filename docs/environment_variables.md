# Production environment variables

Required: `RAILS_ENV=production`, `RAILS_SERVE_STATIC_FILES=true`,
`DATABASE_URL`, `APP_HOST`, `ALLOWED_HOSTS`, `RAILS_MASTER_KEY` and/or
`SECRET_KEY_BASE`, `SMTP_ADDRESS`, `SMTP_USERNAME`, `SMTP_PASSWORD`,
`MAIL_FROM_EMAIL`, `MAIL_FROM_NAME`, `STORAGE_ACCESS_KEY_ID`,
`STORAGE_SECRET_ACCESS_KEY`, `STORAGE_REGION`, and `STORAGE_BUCKET`.
Also required are `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`,
`ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`, and
`ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` for encrypted TOTP secrets, plus
`SECURITY_EVENT_DIGEST_KEY` for network-identifier digests. All of these are
Render secret variables except non-secret mode/settings values.

Optional/configurable: `SMTP_PORT` (587), `STORAGE_ENDPOINT`,
`STORAGE_FORCE_PATH_STYLE`, `RAILS_MAX_THREADS` (3), `DATABASE_POOL`,
`JOB_CONCURRENCY` (1), `DB_STATEMENT_TIMEOUT` (15s), `DB_LOCK_TIMEOUT` (3s),
`DB_IDLE_TRANSACTION_TIMEOUT` (30s), `RAILS_LOG_LEVEL`, `RAILS_LOG_TO_STDOUT`,
`RELEASE_SHA`, `ERROR_REPORTER_ADAPTER`, `MALWARE_SCANNER_ADAPTER`, and
`REPORT_EXPORT_RETENTION_DAYS`.
`REPORT_EXPORT_MAX_ACTIVE` defaults to 3.

Demo mode: `DEMO_MODE=false` is the safe default in every environment. Normal
local development should leave it unset or explicitly false. An isolated,
on-request demo deployment may set `DEMO_MODE=true`. A production deployment
must set it explicitly to false and must not copy an environment group from a
demo service without reviewing it. Demo mode is a presentation and policy
signal, not a substitute for separate databases, storage buckets, SMTP
sandboxes, scanner services, credentials, or network isolation.

Scanner: set `MALWARE_SCANNER_ADAPTER=clamav`, `CLAMAV_HOST`, optional
`CLAMAV_PORT` (3310), and `SCANNER_TIMEOUT_SECONDS` (10). The scanner must be on
a private network. `clean` is deterministic and forbidden as evidence of real
production protection.

Values are never committed. Rate limiting and cache correctness require the
shared Solid Cache database in production; memory stores are development-only.
Rails credentials or the selected secret store must contain no development
values. `ERROR_REPORTER_ADAPTER=logging` is an acceptable launch fallback only
when log alerts and retention are configured. Analytics has no application
variable in this release and should not be invented or configured.
