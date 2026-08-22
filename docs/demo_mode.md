# Demo mode foundation

The deterministic data includes `DEMO-POS-OPEN`, balanced and variance closed
sessions, cash/multi-item/prescription/discount sales and `DEMO-POS-VOID`.
Stable completion keys make a second run reuse records without repeating stock
consumption. Guided links are capability-gated.

Phase 17 adds stable `DEMO-BATCH-EXPIRED`, `DEMO-BATCH-NEAR`, and
`DEMO-BATCH-QUARANTINE` scenarios, receipt-created supplier batches, and
batch-linked reservation consumption. Inventory-manager guidance links to the
Arabic batch inventory screen. Second-run seeding reuses the same fictional
batch numbers and movement keys.

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
orders; active/inactive fictional suppliers; draft, submitted, approved,
partially received, fully received, and cancelled purchase orders; varied
expected dates and purchase costs; and dates distributed across recent weeks for
reports. Purchasing receipts increase product-level stock only—no batch or
expiry data is seeded.

Per-item prescription review (Phase 19) scenarios run through the real
pharmacist decision services, not direct attribute writes: `DEMO-PRESCRIPTION-NEW`
(pending), `DEMO-PRESCRIPTION-REVIEW` (under review), `DEMO-PRESCRIPTION-APPROVED`,
`DEMO-PRESCRIPTION-REJECTED`, `DEMO-PRESCRIPTION-SUBSTITUTED`, a mixed
ordinary+approved+rejected order (`DEMO-PRESCRIPTION-MIXED`), and a substituted
POS sale (`DEMO-POS-RX-SUBSTITUTED`).

Drug safety scenarios (Phase 20) also run through the real evaluation,
acknowledgement and decision services. Four fictional active ingredients
(`DEMO-ALFA`, `DEMO-BETA`, `DEMO-GAMMA`, `DEMO-DELTA`) and four fictional rules
drive `DEMO-SAFETY-INTERACTION` (critical blocking interaction, documented
pharmacist override, then approval), `DEMO-SAFETY-DUPLICATE` (acknowledged
duplicate-ingredient warning), `DEMO-SAFETY-ALLERGY` (open allergy conflict
against a pharmacist-recorded allergen), `DEMO-SAFETY-AGE` (open age caution from
a recorded date of birth) and `DEMO-SAFETY-SUBSTITUTION` (override, then a
substitution that retires the interaction finding and creates a different one).
The demo customer clinical profiles hold fictional dates of birth and one
fictional allergy; the rules are demonstration configuration and carry no real
clinical meaning or guidance. Re-seeding creates no duplicate findings.

Search scenarios (Phase 21) use deterministic products with deliberate Arabic spelling
variety: `demo-alef-syrup` ("شراب إبراهيم") is reachable from the bare-alef spelling
"شراب ابراهيم", and `demo-maqsura-cream` ("اليومى") is reachable from "اليومي". The demo also
covers exact SKU and barcode lookup, brand search, structured active-ingredient search, a
one-character typo ("فتامين" finds "فيتامين"), and a zero-result query. Three linguistic
search synonyms are seeded (singular/plural and one common misspelling); they widen search
only and carry no clinical meaning.

The bundled PDF is synthetic and contains no medical information. The seed task
temporarily uses Active Job's test adapter so prescription scan and mail jobs are
not executed, and suppresses transactional-email enqueueing so exercising the
real prescription-decision pipeline never queues customer notifications. In
production mode the task also refuses to run without
`DEMO_STORAGE_ISOLATED=true`; this is operator confirmation that Active Storage
points to a private demo-only bucket. It never sends invitations.

There is intentionally no `demo:reset` task yet. The singleton pharmacy setting,
append-only audit records, and globally scoped relational graph require a
separately reviewed deletion manifest and ordering before selective removal can
be guaranteed. Never use `db:drop`, `db:reset`, or `db:seed:replant`, and never
place real production records in the demo database.

## Guided journeys

After signing in, `/demo` is the Arabic control center for the demonstration.
It identifies the current role and enables only that role's guided links. The
recommended order is customer, pharmacist, order manager, inventory manager,
then administrator. Scenario links resolve stable order numbers, product slugs,
coupon/promotion references, and account emails at request time; database IDs
are never part of the guide configuration.

Switching journeys means signing out and signing in normally with the other
account. There is no impersonation, passwordless entry, or 2FA bypass. Send the
temporary password privately. For a privileged account, the operator also
provides a current TOTP code without disclosing the shared enrollment secret in
the browser, documentation, or chat transcript.

Use the [demo operator checklist](demo_operator_checklist.md) before, during,
and after every temporary environment. The [Arabic presentation script](demo_presentation_script.md)
provides a focused 10–15 minute route through the seeded scenarios.

## Temporary access lifecycle

1. Start an isolated, disposable environment with its own database, private
   storage, SMTP sandbox, cache, queue, encryption keys, and scanner.
2. Set `DEMO_MODE=true`, configure every demo password and `DEMO_TOTP_SECRET`
   through the environment's secret store, migrate, and run `demo:seed`.
3. Verify customer sign-in and privileged password → TOTP sign-in before
   privately issuing only the accounts needed for the appointment.
4. After the appointment, revoke sessions, rotate demo credentials, inspect
   sanitized logs, stop the service, and delete temporary infrastructure when
   it is no longer required.

Known limitations: demo data is not automatically reset; historical examples
should normally be viewed rather than mutated. The application has no real
payment, SMS, or courier integration. Email, object storage, and malware
scanning require separately isolated demo services when those workflows are
shown. A real-browser run also requires a supported browser installed in the
verification environment.

Phase 22 demo guidance uses fictional completed order/POS sources and stable return identifiers only. Returned batches, dispositions, inspections, and refund markers never trigger external communication or real payment activity.

Phase 23 adds stable fictional rules, points and wallet credit, online earning, expired points, and an identified mixed-payment POS sale. Re-seeding does not duplicate economic value.

Phases 24–27 add three branches for the primary showcase plus an independent `DEMO-B` organization with its own users, branch, products, batches, POS sale, online order, purchase order, loyalty/wallet activity and analytics. Stable `find_or_create`/idempotency keys make a second seed economically neutral. Demo API clients contain no usable plaintext credential and webhooks make no real delivery.
