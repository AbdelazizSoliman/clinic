# MVP launch checklist

Every item requires evidence and an owner. Critical/high failures are no-go.
Never paste secret values, prescription contents, or customer data into this file.

## Code and build

- [ ] Release commit and `RELEASE_SHA` recorded
- [ ] CI test, RuboCop, Brakeman, Bundler audit, Importmap audit, Zeitwerk, and Tailwind green
- [ ] Production Docker image built; multi-stage layers and non-root UID verified
- [ ] Runtime image contains `libvips`/PostgreSQL client and excludes development/test gems
- [ ] Image history and repository secret scan show no credentials
- [ ] Production assets, eager boot, routes, `/up`, `/health/ready`, and `launch:smoke` pass

## Database and recovery

- [ ] Render PostgreSQL SSL, UTC, connection limit, pool, extensions, and current schema verified
- [ ] Backup enabled with approved retention and a pre-migration manual backup
- [ ] Restore tested into an isolated restricted environment; RPO/RTO recorded
- [ ] `db:prepare` completed without timeout; no pending migrations
- [ ] Solid Queue, Solid Cache, and Active Storage tables verified
- [ ] `Operations::IntegrityCheck` has no unexplained critical/high findings

## External services

- [ ] Private encrypted/versioned object bucket; listing/public access denied
- [ ] Temporary fake upload read/delete and product/logo variants verified
- [ ] Prescription ownership and signed URL expiry verified
- [ ] SMTP TLS, sender authentication, production links, tracked delivery/failure/retry verified
- [ ] Web, worker, Solid Queue recurring scheduler, and heartbeat alerts verified
- [ ] Shared Solid Cache and cross-instance Rack::Attack behavior verified
- [ ] Real ClamAV/external scanner: health, clean file, EICAR, failure, timeout, retry, and dashboard verified
- [ ] Error logging/provider synthetic request and job errors captured without sensitive data

## Domain and security

- [ ] Temporary Render URL healthy before DNS change
- [ ] Custom domain, APP_HOST, ALLOWED_HOSTS, HTTPS redirect, HSTS, and no proxy loop verified
- [ ] Apex/www and old Render URL policy approved
- [ ] CSP, headers, secure cookies, CSRF, rate limits, ownership, role boundaries, and 2FA verified
- [ ] Git/image/log secret scan clean; no raw storage keys, tokens, OTPs, addresses, or medical content

## People and operational data

- [ ] Bootstrap admin created by secure task and immediately enrolled in 2FA
- [ ] A second individual admin plus pharmacist, order manager, and inventory manager invited where approved
- [ ] Role access, session invalidation, recovery-code custody, and final-admin protection verified
- [ ] Pharmacy settings, registration/guest/prescription policy, reservation durations, and maintenance off reviewed
- [ ] Catalog, prices, inventory, delivery zones/slots, and promotions deliberately loaded; no demo users/orders/files

## Product QA

- [ ] Journeys A–F completed with isolated test accounts/data and cleaned up
- [ ] Chrome/Chromium, Edge, practical Firefox, 390px, tablet, RTL, Turbo/back-forward, upload, and admin tables checked
- [ ] Safari/iPhone explicitly recorded as tested or unavailable
- [ ] Keyboard-only flows, headings, labels, focus, live regions, errors, contrast, touch targets, and reading order checked
- [ ] Controlled limited load test completed without pool exhaustion, corruption, or queue accumulation

## Go/no-go

- [ ] Monitoring contacts and first-hour/day on-call ownership confirmed
- [ ] Rollback image/version identified; worker/scheduler stop and maintenance procedures rehearsed
- [ ] Non-reversible migration and post-write rollback implications reviewed
- [ ] Open blockers table contains no unresolved critical/high item
- [ ] Named business/engineering go-live approval recorded

## Launch blockers

| Blocker | Severity | Owner | Reproduction/evidence | Fix | Verification | Status |
|---|---|---|---|---|---|---|
| Docker build environment unavailable locally | High | Engineering | `docker` absent in WSL | Run CI Docker verification | Image boot/health evidence | Open |
| Real production services and credentials not configured | Critical | Production owner | No Render deployment authorized | Configure through Render secrets | Full smoke evidence | Open |
| Real scanner not verified | Critical when prescriptions enabled | Security/operations | No ClamAV service | Configure and test, or disable prescription review | Clean/EICAR/fail-closed evidence | Open |
| Real browser E2E incomplete | High | QA | No local browser/system tests | Run browser matrix and journeys A–F | Screenshots/checklist without sensitive data | Open |
| Backup restore unverified | Critical | Production owner | No production database exists | Enable backup and isolated restore drill | Restore report | Open |

## Rollback decision

1. Stop scheduler and worker if jobs could amplify damage; enable maintenance.
2. Roll web and worker to the recorded prior image together.
3. Do not reverse the database after production writes unless the migration and
   data consequences were explicitly reviewed. Prefer a forward fix.
4. Restore a database only for confirmed data loss/corruption using the tested
   backup; preserve object storage and logs. Validate database/object consistency.
5. Disable registration and prescription review when those paths are unsafe;
   revoke compromised sessions and rotate affected credentials.
6. Communicate with public order identifiers only—never medical/customer data.
