# Demo mode foundation

Set `DEMO_MODE=true` only on an isolated demonstration deployment. The default
is false. Application code queries `DemoMode.enabled?` (or `demo_mode?` in
controllers and views); it must not read `DEMO_MODE` directly.

When enabled, authenticated interfaces display an Arabic demo banner and expose
`/demo`. `DemoMode::SafetyPolicy` is the central extension point for later
protected actions. Phase 15A intentionally configures no protected actions, so
existing commerce and administration behavior is unchanged.

## External side-effect audit

- Transactional notification and invitation jobs can send SMTP email. Demo
  deployments must use an isolated SMTP sandbox or provider sandbox account.
  Delivery is not disabled in application code because silently suppressing a
  message while marking `TransactionalEmailDelivery` delivered would make the
  operational record false.
- Prescription, product, category, brand, pharmacy-logo, and report-export
  attachments write to Active Storage. Use a private demo-only bucket and never
  upload real medical or personal documents.
- Prescription uploads enqueue ClamAV scans. Use an isolated scanner endpoint;
  the existing production behavior remains fail-closed when the scanner is
  missing or unavailable.
- Checkout supports cash on delivery only. Card and wallet values are
  placeholders and are rejected; there is no payment-provider integration.
- No SMS provider or courier integration is present.
- External error reporting is only active when explicitly configured. A demo
  should retain the logging adapter unless a separately reviewed sandbox is
  supplied.

Demo mode does not make shared infrastructure safe. Never share its database,
bucket, SMTP credentials, encryption keys, or scanner with a real production
environment.
