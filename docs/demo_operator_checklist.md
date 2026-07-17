# Demo operator checklist

This checklist is for a temporary, isolated portfolio demonstration. Never use
a production database, bucket, credentials, or real patient/customer data.

## Before the demo

- Verify the intended branch and commit; ensure the working tree is understood.
- Confirm `DEMO_MODE=true` only in the disposable demo environment.
- Confirm the database, private object storage, cache/queue, encryption keys,
  SMTP sandbox, and malware scanner are isolated from production.
- Configure demo passwords and the privileged TOTP seed in the platform secret
  store. Do not paste them into logs, source, documentation, or a ticket.
- Run migrations, then `bin/rails demo:seed`; a second run should report the
  same stable records without duplicates.
- Sign in as the customer. Then verify each privileged account follows the
  normal password → current TOTP flow.
- Verify the synthetic prescription attachment is clean and accessible only to
  the authorized customer/pharmacist. Never upload a real prescription.
- Open `/demo`, the prescription queue, stock dashboard, fulfilment queue, and
  the last-30-days reports. Confirm their seeded examples are present.
- Confirm payment, SMS, and courier integrations are absent, and that email is
  sandboxed. Confirm storage and scanner failures remain fail-closed.

## During the demo

1. Customer: storefront → search → cart with `DEMO10` → delivery → existing
   `DEMO-DELIVERED-OLD` → prescription product.
2. Pharmacist: `DEMO-PRESCRIPTION-REVIEW` and the approved/rejected examples.
3. Order manager: `DEMO-CONFIRMED` → `DEMO-PREPARING` → `DEMO-READY` →
   `DEMO-OUT-FOR-DELIVERY` → historical cancellation.
4. Inventory manager: physical/reserved/available stock, low/zero stock,
   movements, and inventory report.
5. Administrator: users, settings, `demo:active-cart`/`DEMO10`, delivery zones,
   reports, and security operations.

Prefer viewing seeded historical records. Create a fresh customer order only
when there is enough time and the operator intends to mutate the disposable
dataset. Explain that all people, addresses, medical material, and transactions
are fictional; no medical advice or external fulfilment occurs.

## After the demo

- Sign out all open browsers and revoke privileged sessions.
- Rotate every issued password and the demo TOTP seed before reuse.
- Stop the web, worker, and scheduler processes.
- Delete temporary services and storage when retention is no longer needed.
- Retain no evaluator personal data or uploaded documents.
- Review sanitized logs for accidental credentials or personal data and follow
  the incident runbook if anything sensitive was exposed.
