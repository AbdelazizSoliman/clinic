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

## Demo dataset

Run the dedicated seed only after enabling demo mode:

```bash
DEMO_MODE=true bin/rails demo:seed
```

The task creates stable `@example.test` accounts, `demo-*` catalog and delivery
identifiers, `DEMO-*` order numbers, and `demo:` movement/cart identifiers. It
is repeatable and does not invoke `db:seed`. A second run updates mutable demo
records and reuses immutable order scenarios rather than duplicating them.

Accounts shown on `/demo` cover administrator, pharmacist, order manager,
inventory manager, and customer roles. Passwords come from the variables listed
in `docs/environment_variables.md`. Development may use the intentionally weak
fallback `DemoOnly123!`; it is unavailable in non-development environments.
Privileged accounts are enrolled with `DEMO_TOTP_SECRET`; development uses a
well-known demo-only seed. Configure that seed in a separate authenticator and
never reuse it for a real account.

The dataset includes healthy, low, zero, reserved, released, and consumed stock;
active/expired/future promotions; varied delivery zones; cart-ready, prescription,
confirmed, preparing, ready, dispatched, delivered, rejected, and cancelled
orders; and dates distributed across recent weeks for reports.

The bundled PDF is synthetic and contains no medical information. The seed task
temporarily uses Active Job's test adapter so prescription scan and mail jobs are
not executed. In production mode the task also refuses to run without
`DEMO_STORAGE_ISOLATED=true`; this is operator confirmation that Active Storage
points to a private demo-only bucket. It never sends invitations.

There is intentionally no `demo:reset` task yet. The singleton pharmacy setting,
append-only audit records, and globally scoped relational graph require a
separately reviewed deletion manifest and ordering before selective removal can
be guaranteed. Never use `db:drop`, `db:reset`, or `db:seed:replant`, and never
place real production records in the demo database.
