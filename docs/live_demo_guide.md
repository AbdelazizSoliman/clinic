# Live demonstration guide

This expands the [operator checklist](demo_operator_checklist.md) into three
audience-facing routes. Complete that checklist before and after every session.
Use only an isolated environment and fictional demo data. Credentials and TOTP
values are issued privately and never shown in slides, chat, recordings, logs,
or repository documentation.

## Shared operating rules

- Open `/demo` after each role signs in. Use its authorized stable links instead
  of guessing database IDs or manually searching when time is limited.
- Prefer seeded historical records. Do not mutate protected demo users,
  promotions, or completed/cancelled examples.
- If live checkout is not an agreed part of the session, stop at the checkout
  review page and open `DEMO-DELIVERED-OLD` for the outcome.
- Never upload a real prescription or display document content. Use the seeded
  synthetic record and discuss states and authorization.
- Do not open server configuration, environment variables, storage URLs,
  developer tools, Rails consoles, logs, or recovery-code screens.
- Call the implemented payment method “cash on delivery.” Do not suggest that a
  gateway, SMS, courier, ERP, WhatsApp, branches, suppliers, or safety engine is
  already connected.
- If an expected seeded link is missing, do not improvise by changing data.
  move to the relevant screenshot and explain that the operator will inspect
  the isolated seed after the session.

## Five-minute version

### 0:00–0:30 — Frame the product

**Click:** Sign in as the customer and open `/demo`.

**Explain:** “This is an Arabic RTL pharmacy commerce and operations portfolio.
The records are deterministic and fictional, and each role still uses normal
authentication and authorization.”

**Avoid:** infrastructure settings, credentials, compliance claims, and a long
technology list.

### 0:30–1:30 — Customer commerce

**Click:** Storefront → seeded cart with `DEMO10` → checkout review.

**Explain:** Arabic RTL discovery; promotion and totals visibility; address,
delivery-zone, method, capacity, stock, and prescription validation. Checkout
creates snapshots and reservations transactionally.

**Avoid:** submitting a new order. State that payment is cash on delivery.

### 1:30–2:20 — Prescription boundary

**Click:** Sign out; sign in as pharmacist with password then current TOTP;
`/demo` → `DEMO-PRESCRIPTION-REVIEW`.

**Explain:** private files are validated and scan-gated; pharmacists receive a
focused decision workflow. Approval can allow progression; rejection releases
unconsumed commitments.

**Avoid:** opening document content or giving a clinical opinion.

### 2:20–3:20 — Fulfilment

**Click:** Switch to order manager; `/demo` → fulfilment workflow showing
`DEMO-PREPARING`, `DEMO-READY`, and `DEMO-OUT-FOR-DELIVERY`.

**Explain:** explicit states, staff hand-offs, optimistic locking, repeat-safe
services, events, and notifications.

**Avoid:** changing seeded historical orders.

### 3:20–4:20 — Inventory

**Click:** Switch to inventory manager; `/demo` → inventory dashboard.

**Explain:** physical, reserved, and available stock; reservation consumption
creates append-only physical movements, while cancellation releases stock that
was committed but never removed.

**Avoid:** manual stock adjustments during a short demo.

### 4:20–5:00 — Close

**Click:** Show reports screenshot or, if already signed in as admin, the
last-30-days reports.

**Explain:** one Rails/PostgreSQL workflow connects commerce and operations;
there is no permanent public deployment. Invite one focused question.

**Avoid:** rushing through settings, users, or roadmap modules.

## Ten-minute version

### 0:00–1:00 — Introduction and guided center

**Click:** Customer sign-in → `/demo`.

**Explain:** fictional data, five roles, stable scenarios, normal authorization,
and the temporary-demo model. Point out the RTL layout and role-aware links.

**Avoid:** presenting demo mode as an infrastructure security boundary.

### 1:00–3:00 — Storefront, cart, and checkout

**Click:** Storefront → one catalog search/filter → cart with `DEMO10` →
checkout review → `DEMO-DELIVERED-OLD`.

**Explain:** customer flow, delivery validation, cash on delivery, and immutable
name/price/address/delivery/promotion snapshots in the historical order.

**Avoid:** completing checkout unless mutation was planned and time is reserved.

### 3:00–4:30 — Prescription review

**Click:** Pharmacist sign-in with TOTP → `/demo` → review queue →
`DEMO-PRESCRIPTION-REVIEW`.

**Explain:** extension/MIME/size/count and bounded signature checks; asynchronous
scanner boundary; fail-closed state; scoped pharmacist access; explicit review
edges and safe customer follow-up.

**Avoid:** claiming the scanner is active without verified service
configuration, showing documents, or discussing drug suitability.

### 4:30–6:00 — Order and fulfilment

**Click:** Order-manager sign-in → `/demo` → fulfilment board → inspect one
preparing and one dispatched order.

**Explain:** order and fulfilment transitions are distinct but coordinated;
services own authorization, locking, events, and side effects.

**Avoid:** prescription-file links—the role should not have them.

### 6:00–7:30 — Inventory integrity

**Click:** Inventory-manager sign-in → dashboard → movement history.

**Explain:** reservations prevent the same available stock being promised twice;
consumption occurs at ready-for-delivery and movement arithmetic is append-only.

**Avoid:** saying lots, batches, expiry, or FEFO exist.

### 7:30–9:00 — Administration and reporting

**Click:** Admin sign-in with TOTP → reports for last 30 days → promotion
`demo:active-cart` / coupon `DEMO10`.

**Explain:** reports are role-scoped; CSV output is formula-safe; queued exports
are private and expire. Promotions preserve scope, timing, limits, and snapshots.

**Avoid:** triggering exports if workers/storage were not pre-verified.

### 9:00–10:00 — Architecture and limits

**Click:** Return to the guided center or a prepared architecture diagram.

**Explain:** Rails modular monolith, PostgreSQL transactions/locks, Hotwire,
Solid Queue, and why local transactions fit the workflow. State single-pharmacy,
COD, external-service, and deployment boundaries.

**Avoid:** reading the full roadmap. Ask which path the audience wants to
inspect more deeply.

## Twenty-minute version

### 0:00–2:00 — Context and scope

**Click:** Customer sign-in → `/demo`.

**Explain:** business coordination problem, five roles, deterministic fictional
data, and normal authentication. Describe current scope before features.

**Avoid:** real-client, production-traffic, or compliance claims.

### 2:00–5:00 — Customer journey

**Click:** Storefront → search/filter → ordinary product → prescription-required
product → cart with `DEMO10` → checkout review.

**Explain:** Arabic RTL with server rendering, availability, visible
prescription rules, cart calculation, delivery matching/capacity, and COD.

**Avoid:** uploading or ordering unless a disposable mutation was planned.

### 5:00–7:00 — Historical order integrity

**Click:** Customer order history → `DEMO-DELIVERED-OLD`.

**Explain:** submitted names, categories, brands, prices, customer/address,
delivery, promotions, and totals are snapshots; later catalog changes cannot
rewrite the order. Mention the checkout submission token and atomic creation.

**Avoid:** describing snapshots as a general event-sourcing implementation.

### 7:00–10:00 — Prescription and role isolation

**Click:** Pharmacist password → TOTP → queue →
`DEMO-PRESCRIPTION-REVIEW`; compare seeded approved and rejected states.

**Explain:** private authorized download path, validation, scan gating,
optimistic version, decision transitions, and resulting order/reservation
behavior. Contrast pharmacist access with order-manager limitations.

**Avoid:** file content, live medical decisions, scanner-effectiveness claims,
or claiming a drug-safety engine.

### 10:00–12:30 — Fulfilment hand-offs

**Click:** Order-manager sign-in → `DEMO-CONFIRMED` → `DEMO-PREPARING` →
`DEMO-READY` → `DEMO-OUT-FOR-DELIVERY`; view `DEMO-CANCELLED` historically.

**Explain:** allowed order edges, fulfilment assignment and states, inventory
consumption boundary, event trail, notification separation, and safe repeated
operations.

**Avoid:** mutating the prepared examples or suggesting courier integration.

### 12:30–15:00 — Inventory evidence

**Click:** Inventory-manager sign-in → dashboard → low/zero/reserved examples →
movement history.

**Explain:** physical/reserved/available calculation; product/reservation locks;
movement before/delta/after invariant; release versus return-to-stock.

**Avoid:** showing cost data unless relevant and authorized; do not claim lot,
expiry, FEFO, purchasing, or supplier support.

### 15:00–17:30 — Admin, promotions, and reports

**Click:** Admin sign-in with TOTP → users/roles briefly → promotion and coupon
→ last-30-days reports → security/operations dashboard.

**Explain:** protected demo identities, promotion schedules and limits,
role-scoped reports, private exports, job visibility, readiness and integrity
checks.

**Avoid:** changing demo accounts/promotions, exposing recovery information, or
triggering unverified external services.

### 17:30–19:00 — Architecture and quality

**Click:** Prepared system-context and order/inventory diagrams.

**Explain:** controller, service, model, job, and external boundaries; why a
modular monolith keeps transactions local; test types, CI audit/build checks,
Docker verification, and deterministic seed tests.

**Avoid:** quoting a stale test count or claiming deployed production evidence.

### 19:00–20:00 — Limits and discussion

**Click:** Prepared limitations/roadmap slide.

**Explain:** one pharmacy, COD, temporary demonstration, and separately
configured external services. Clearly label every future module as planned.

**Avoid:** feature negotiation during the tour. Record follow-up requirements
for a later scoped conversation.

## Common questions during a demo

**Why Rails instead of a separate API and SPA?**

The connected workflow benefits from local transactions and server-side
authorization. Hotwire adds responsiveness without duplicating validation and
permissions in a second application. A future API would need its own explicit
requirements and authorization design.

**How do you prevent overselling?**

Checkout locks relevant product rows and creates active reservations. Available
stock subtracts those reservations. Consumption locks products and reservations
again before changing physical stock and recording idempotent movements.

**Are prescription files public?**

No. The design uses private storage and an authorized application route. File
validation and scan state gate access; real storage and scanner services still
need operator configuration.

**Is it compliant with pharmacy or privacy regulation?**

No certification is claimed. The repository demonstrates technical safeguards;
a real launch requires market-specific legal, privacy, medical, security, and
operational review.

**Can it scale?**

The repository demonstrates database consistency, background work, caching,
health checks, and a production image, but it has no production-traffic evidence
or permanent deployment. Capacity targets require measurement in the intended
environment.

**Why no microservices?**

The most important operations span tightly related order, stock, promotion, and
fulfilment records. A modular monolith makes those transactions explicit and
avoids distributed consistency overhead at the current scope.

**Can it support branches, online payment, or integrations?**

They are possible extension areas, not implemented claims. Each changes data,
failure, reconciliation, authorization, and operational boundaries and must be
scoped separately. See the [client FAQ](client_faq.md).

**Can I access a public demo later?**

There is no permanent public demo. A temporary isolated session can be arranged
and its access is revoked afterward.
