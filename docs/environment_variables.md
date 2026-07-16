# Production environment variables

Required: `DATABASE_URL`, `APP_HOST`, `ALLOWED_HOSTS`, `RAILS_MASTER_KEY` (or
`SECRET_KEY_BASE` plus Active Record encryption configuration), `SMTP_ADDRESS`,
`SMTP_USERNAME`, `SMTP_PASSWORD`, `STORAGE_ACCESS_KEY_ID`,
`STORAGE_SECRET_ACCESS_KEY`, `STORAGE_REGION`, and `STORAGE_BUCKET`.
Also required are `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`,
`ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`, and
`ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` for encrypted TOTP secrets.

Optional/configurable: `SMTP_PORT` (587), `STORAGE_ENDPOINT`,
`STORAGE_FORCE_PATH_STYLE`, `RAILS_MAX_THREADS` (3), `DATABASE_POOL`,
`JOB_CONCURRENCY` (1), `DB_STATEMENT_TIMEOUT` (15s), `DB_LOCK_TIMEOUT` (3s),
`DB_IDLE_TRANSACTION_TIMEOUT` (30s), `RAILS_LOG_LEVEL`, `RAILS_LOG_TO_STDOUT`,
`RELEASE_SHA`, `ERROR_REPORTER_ADAPTER`, `MALWARE_SCANNER_ADAPTER`, and
`REPORT_EXPORT_RETENTION_DAYS`.
`REPORT_EXPORT_MAX_ACTIVE` defaults to 3.

Scanner: set `MALWARE_SCANNER_ADAPTER=clamav`, `CLAMAV_HOST`, optional
`CLAMAV_PORT` (3310), and `SCANNER_TIMEOUT_SECONDS` (10). The scanner must be on
a private network. `clean` is deterministic and forbidden as evidence of real
production protection.

Values are never committed. Rate limiting and cache correctness require the
shared Solid Cache database in production; memory stores are development-only.
