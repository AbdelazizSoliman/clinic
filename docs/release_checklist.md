# Canonical release checklist

Status markers: `[x]` verified, `[~]` verified with a stated limitation,
`[ ]` outstanding.

## Data and domain integrity

- [x] Baseline branch, SHA, runtime/tool versions recorded.
- [x] Populated database migrated without selected record-count changes.
- [x] Clean PostgreSQL database migrated from zero.
- [x] Test schema prepared and no pending migrations found.
- [~] Safe newest rollback/reapply verified; full historical rollback not claimed.
- [x] Tenant controller IDOR and service-input isolation tests pass.
- [x] Branch allocation, reports, purchasing and transfer isolation tests pass.
- [x] Inventory integrity and representative FEFO workflows pass.
- [x] Financial integrity, loyalty/wallet and return tests pass.
- [x] Clinical authorization, per-line review, substitution and safety gates pass.
- [x] Search, POS, online ordering, purchasing and returns focused tests pass.

## Integrations, analytics and jobs

- [x] API authentication, scopes, isolation, idempotency, rate/error tests pass.
- [x] Webhook secret/signature/retry and SSRF URL-policy tests pass with no real delivery.
- [x] Tenant/branch analytics and CSV authorization tests pass.
- [x] Tenant-sensitive jobs serialize organization IDs and establish/clear context.
- [x] Read-only tenant, inventory and financial integrity tasks return `OK`.

## Build, security and CI

- [x] Full Rails test suite passes with exact totals recorded in release notes.
- [x] RuboCop, Brakeman, bundler-audit, importmap audit and Zeitwerk pass.
- [x] Tailwind build and `git diff --check` pass.
- [x] CI retains test, lint, Ruby security, JS security and Docker jobs.
- [x] No SonarCloud workflow is configured; no SonarCloud claim is made.
- [x] Existing Brakeman ignore reviewed; no new ignore added.
- [ ] Docker image rebuilt locally for this release candidate.

## Demo, browser and portfolio

- [x] Isolated deterministic demo seed run twice with matching manifest/economic totals.
- [x] Demo safety design suppresses external jobs and uses fictional identities.
- [ ] Current desktop 1440×1000 browser journey verified.
- [ ] Current mobile 390×844 browser journey verified.
- [ ] Release 1.0 screenshots captured and sanitized.
- [~] Practical accessibility checklist documented; browser execution unavailable.
- [x] README and canonical Release 1.0 documents no longer describe Phase 16–27 as future scope.
- [x] Release notes and this checklist created.

## Repository hygiene and deployment boundary

- [x] High-confidence tracked-file secret scan reviewed clean.
- [x] Temporary/generated-file audit found no tracked release artifacts.
- [x] Relative documentation links and retained image dimensions verified.
- [~] LICENSE absent; owner decision required.
- [x] Implemented, externally configured, and not-production-verified boundaries documented.
- [x] Final full verification rerun after documentation changes.
- [x] At the 2026-08-27 baseline audit, commit
  `67b7947c3fbf29c8c4964929582efccbe4294dd3` contained the intended Release 1.0
  state. This historical result does not certify later or uncommitted changes.
- [x] No commit, push, merge, deployment, paid infrastructure, credential publication,
  marketplace update, real payment, or external webhook delivery performed.
