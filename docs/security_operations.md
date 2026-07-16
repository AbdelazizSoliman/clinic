# Security operations

Privileged roles must enroll TOTP before operational access. Secrets use Active
Record encryption; recovery codes are shown once, stored only as SHA-256 digests,
and consumed once. An administrator cannot read a TOTP secret. Compromise
response is: deactivate the account, revoke all sessions, rotate affected
credentials, preserve logs/security events, and require controlled 2FA recovery.

Security events are append-only and store a keyed IP digest, short user-agent
summary, safe metadata, and no credentials. Retention is unresolved pending
business/legal approval. Review locked privileged accounts, missing 2FA,
malware-scan failures, failed jobs/mail, and stale heartbeats daily.

Rack::Attack limits authentication and coupon attempts. Production uses shared
Solid Cache; do not replace it with process memory. Only the trusted platform
proxy may set forwarding headers.

Browser sessions use encrypted Rails cookies, `HttpOnly`, `SameSite=Lax`, a
12-hour expiry, and `Secure` in production. Password, role, active-state, and
2FA resets must increment `session_version`; the administrator revoke action
invalidates every existing browser session without exposing tokens.

Prescription scanning is a fail-closed integration boundary: records move from
`pending` to `clean`, `infected`, or `failed`, and staff downloads require
`clean`. Development/test use the deterministic clean adapter. Production must
configure and implement an approved ClamAV or external-service adapter before
launch; no real malware protection is configured by this repository alone.

The included ClamAV INSTREAM client uses a private TCP endpoint, bounded 64 KiB
chunks, connection/read timeouts, three background retries, and records only a
safe failure class. Configure `clamav` only after network isolation, scanner
signature updates, capacity, monitoring, and the dashboard health warning have
been verified. The deterministic `clean` adapter is for tests/development only.

An external error reporter can be connected by implementing
`Errors::Reporter::ExternalAdapter` for Sentry, Honeybadger, Bugsnag, or another
reviewed provider. Only the allowlisted safe context may cross that boundary;
provider SDK automatic request-body and attachment capture must remain disabled.
