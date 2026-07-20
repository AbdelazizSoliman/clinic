# Presentation deck outline

This 14-slide outline is suitable for a portfolio review, technical interview,
or client conversation. Use the wording appropriate to the audience and retain
the limitations slide. Do not turn roadmap items into product screenshots.

## 1. Saydaliyati

- Arabic RTL pharmacy commerce and operations.
- Rails engineering portfolio; temporary private demo available on request.
- Visual: Arabic storefront.
- Speaker point: all shown people, prescriptions, and transactions are
  fictional.

## 2. The coordination problem

- A pharmacy order can involve delivery, private documents, held stock,
  pharmacist decisions, staff hand-offs, and stable commercial history.
- Disconnected CRUD screens allow totals, stock, and states to disagree.
- Visual: compact connected-workflow text from the README, not a feature wall.

## 3. Product solution

- One application for customer, pharmacist, order, inventory, and admin roles.
- Complexity appears when required: ordinary orders remain simple;
  prescription-required orders enter a controlled review path.
- Visual: storefront and pharmacist-review contrast.

## 4. Customer workflow

- Catalog/search → cart/coupon → address and delivery → COD checkout → history.
- Delivery zones, methods, fees, minimums, and scheduled capacity are validated.
- Visual: cart and checkout captures.

## 5. Prescription workflow

- Bounded upload → signature checks → asynchronous scan state → authorized
  pharmacist review → approval or safe rejection consequences.
- Private application routes; pending, failed, or infected states remain gated.
- Visual: pharmacist review. Do not show prescription content or make clinical
  claims.

## 6. Order and fulfilment workflow

- Explicit allowed order states and picking, packing, dispatch, delivery steps.
- Optimistic locking, repeat safety, events, and notifications support hand-offs.
- Visual: fulfilment board.

## 7. Inventory integrity

- Physical − active reservations = available-to-sell.
- Checkout reserves; ready-for-delivery consumes; rejection/cancellation
  releases unconsumed commitments.
- Append-only movements reconcile before, delta, and after values.
- Visual: inventory dashboard and movement history.

## 8. Architecture

- Rails modular monolith, PostgreSQL source of truth, server-rendered Hotwire.
- Controllers enforce HTTP/authorization boundaries; focused services own
  multi-record transitions; jobs isolate asynchronous delivery work.
- External boundaries: private storage, SMTP, scanner, optional error reporter.
- Visual: `diagrams/system_context.mmd`, rendered for the slide if needed.

## 9. Consistency boundaries

- Atomic, idempotent checkout with deterministic locking.
- Immutable order/item/address/promotion snapshots.
- Database uniqueness, optimistic versions, arithmetic invariants, and
  idempotency keys.
- Visual: `diagrams/order_inventory_flow.mmd` or a short reservation sequence.

## 10. Security and privacy boundaries

- Server-side role capabilities and scoped record loading.
- Devise, account locking, TOTP 2FA, single-use recovery codes, session
  invalidation.
- Private files/exports, allowlists and signature checks, fail-closed scanning,
  rate limits, CSP/headers, filtered parameters.
- State explicitly: safeguards are not a compliance certification.

## 11. Reporting and operations

- Role-scoped reports, formula-safe CSV, private queued exports and expiry.
- Solid Queue/Cache, heartbeats, health/readiness, integrity checks, structured
  logs, and provider-neutral error reporting.
- Visual: reports dashboard.

## 12. Demo and quality evidence

- Deterministic fictional graph with stable business identifiers and repeatable
  seed behavior.
- Normal passwords, TOTP, sessions, and authorization; no impersonation bypass.
- Minitest across models/services/requests/jobs/authorization; CI audits,
  assets, framework loading, and Docker checks.
- Visual: guided demo center and mobile storefront.

## 13. Current limits and roadmap

- Current: one pharmacy, cash on delivery, no permanent public deployment.
- External services require operator configuration and verification.
- Roadmap sequence: suppliers/purchasing; lots/expiry/FEFO; POS; per-item review;
  safety rules; search; returns; loyalty; branches; tenancy; APIs; analytics.
- Say “planned,” never “supported,” for every roadmap item.

## 14. Lessons learned and discussion

- Model commitments separately from physical events.
- Preserve historical commercial facts at submission time.
- Put authorization and transitions at server/service boundaries.
- Deterministic demo data is an engineering feature, not just presentation work.
- Close with an invitation to inspect one code path or run a focused private
  demo rather than repeating the full feature list.

