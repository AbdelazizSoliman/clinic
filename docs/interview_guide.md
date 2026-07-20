# Technical interview guide

These concise answers are grounded in the current repository. Expand an answer
by opening the linked path in the [technical reviewer guide](reviewer_guide.md),
not by adding hypothetical capabilities.

## Rails

**Why use a Rails modular monolith?**

Checkout and operational transitions span order, inventory, promotion,
prescription, and fulfilment data. One Rails/PostgreSQL boundary keeps those
transactions local, while namespaces and focused service objects keep domain
responsibilities explicit.

**What belongs in controllers, models, and services?**

Controllers enforce HTTP authentication, scoped loading, and response behavior.
Models own associations, validations, enums, and local invariants. Services own
authorized multi-record decisions, locking, state transitions, and transaction
boundaries.

**Why service objects instead of callbacks?**

Important side effects need visible ordering, authorization, repeat behavior,
and error results. Services such as `Orders::CreateFromCart` and
`Inventory::ConsumeReservations` make those workflows directly testable and
avoid hiding cross-domain changes behind lifecycle callbacks.

**How is background work used?**

Active Job with Solid Queue handles transactional mail delivery, prescription
scanning, report exports, reservation/invitation expiry, and cleanup. Business
transactions complete independently of external delivery attempts, with status
and retry visibility recorded separately.

**Why stable business identifiers?**

Order numbers, product slugs, SKUs, promotion references, and demo emails are
meaningful outside the database. Demo guidance can resolve reproducible
scenarios without exposing primary keys or coupling documentation to insertion
order.

## Architecture

**Where are the main boundaries?**

The application contains identity, catalog, cart/checkout, prescriptions,
orders, inventory, fulfilment/delivery, promotions, reports, operations, and
demo tooling. PostgreSQL is the source of truth; private storage, SMTP, a
scanner, and optional error reporting sit behind external boundaries.

**How do you keep modules separated in one codebase?**

Services and queries are domain-namespaced, role capabilities limit entry
points, and models expose focused invariants. Multi-domain coordination is
explicit in orchestration services rather than spread across controllers.

**Why not microservices?**

The current risks are transactional consistency and authorization, not
independent organizational scaling. Splitting checkout and inventory would add
distributed transactions, messaging, and failure recovery without evidence that
the current product needs that cost.

**How are external providers handled?**

Storage, SMTP, malware scanning, and error reporting are configured boundaries.
Scanner and reporting adapters have safe results/timeouts, and job failures do
not roll back already-completed business transactions. Real services must still
be provisioned and verified by an operator.

**How would you evolve the architecture?**

Start from a measured constraint. Add caching, query/index improvements, worker
capacity, or read separation when evidence supports it. Introduce an API or
service boundary only with concrete consumers, ownership, consistency, and
failure requirements.

## Hotwire and frontend

**Why Hotwire rather than React or another SPA?**

Server rendering keeps Arabic content, validation, sessions, and authorization
in one application. Turbo and small Stimulus controllers enhance navigation and
interaction without maintaining a duplicated API/client model.

**How is Arabic RTL supported?**

Views use semantic Arabic markup, document direction, direction-aware layouts,
and responsive Tailwind utilities. Phase 15E reviewed desktop and 390-pixel
Chrome captures for direction and document-level overflow.

**What belongs in Stimulus?**

Small browser-only interaction behavior. Business validation, permissions, and
state transitions remain server-side so disabling JavaScript cannot bypass
workflow rules.

**What are the trade-offs of this approach?**

It reduces frontend duplication and operational complexity, but very rich
offline or highly interactive client experiences could justify a different
boundary later. That requirement is not present in the current project.

## Database and consistency

**What happens during checkout?**

The service validates owned address and delivery choices, locks the cart,
products, relevant promotions/coupon, and scheduled slot, recalculates prices,
then creates order records, immutable snapshots, reservations, fulfilment,
promotion/redemption records, and any prescription within one transaction.

**How is checkout idempotent?**

A submission token prevents repeated requests from creating duplicate orders.
Database uniqueness constraints reinforce important identities rather than
depending only on application checks.

**Where do you use pessimistic and optimistic locking?**

Pessimistic row locks protect concurrent stock, slot, promotion, and checkout
decisions. Optimistic `lock_version` checks reject stale staff/admin transitions
where a human may act on an outdated page.

**Why snapshot order data?**

Names, categories, brands, prices, customer/address, delivery terms, promotions,
and totals describe what was submitted. Reading current catalog/settings later
would silently rewrite commercial history.

**How are monetary totals protected?**

Calculation services use deterministic order-boundary arithmetic, and the order
model validates that stored components reconcile. Promotion snapshots retain
the applied commercial context.

**Is this event sourcing?**

No. The system uses current-state relational models plus append-only inventory
movements and order events where history matters. It does not rebuild all
application state from a universal event log.

## Security

**How is authorization enforced?**

Roles expose server-side capability methods; controllers scope records and
services recheck permission for sensitive transitions. Hidden navigation is a
convenience, never the security boundary.

**How does privileged authentication work?**

Privileged roles use Devise password authentication followed by TOTP. Secrets
are encrypted, recovery codes are stored as digests and consumed once, and a
session version invalidates older sessions after sensitive identity or 2FA
changes.

**How are prescription uploads protected?**

The application restricts count, size, extension and MIME type, performs bounded
magic-byte checks, stores files privately, and serves them through an authorized
route. Pending, failed, or infected scan states remain inaccessible for normal
review.

**Does malware scanning make uploads safe?**

It is one defense layer, not a guarantee. The repository supplies the adapter,
timeouts, and fail-closed states; an operator must configure, update, monitor,
and test the real scanner service.

**What other controls exist?**

Account locking, CSRF protection, CSP and security headers, Rack::Attack rate
limits, sensitive-parameter filtering, private export ownership checks,
security events, and integrity checks. None is presented as regulatory
certification.

**How are secrets handled in demos?**

Passwords and TOTP seeds come from an isolated environment's secret store. They
are issued privately, never committed or displayed, then rotated and sessions
revoked after a temporary demo.

## Inventory

**What is the difference between physical, reserved, and available stock?**

Physical stock is the product quantity on hand. Active reservations are units
committed to submitted orders but not yet consumed. Available-to-sell is
physical minus active reservations.

**Why not decrement stock at checkout?**

Prescription and fulfilment workflows may keep an order pending. Reserving stock
prevents it from being promised again while preserving the distinction between
a commitment and a physical removal.

**When is stock consumed?**

At the ready-for-delivery transition. The service locks relevant products and
reservations in deterministic order, verifies quantities, decrements physical
stock, marks reservations consumed, and writes one idempotent movement per
reservation within a transaction.

**What happens on cancellation or prescription rejection?**

Active reservations are released because physical stock was never removed.
Consumed reservations prevent unsafe cancellation paths. Eligible promotion
redemptions can also be released.

**Why append-only movements?**

Each accepted physical change records before, delta, and after values with a
business reference. Update and delete are blocked, so investigation does not
depend on mutable history.

**Does inventory support batches, expiry, or FEFO?**

No. Current stock is product-level. Lots, batches, expiry-aware allocation,
FEFO, suppliers, and purchasing are explicit roadmap items.

## Testing and quality

**What does the suite cover?**

Minitest covers models, services, queries, requests/integration, jobs,
authorization, security, concurrency-sensitive stock/promotion/slot behavior,
exports, mail retry, health boundaries, and deterministic demo behavior.

**How do you test authorization?**

Request tests exercise cross-role and ownership boundaries, including medical
files, inventory cost, reports/exports, and administration. Sensitive services
also authorize rather than trusting the controller alone.

**How do you test concurrency?**

High-risk tests drive competing stock, promotion, delivery-slot, and
administrative operations, while implementation relies on locks and database
constraints. The goal is to test the invariant and the losing request behavior,
not merely a happy path.

**What runs in CI?**

The repository workflow runs PostgreSQL-backed tests, RuboCop, Brakeman,
dependency/importmap audits, Zeitwerk, Tailwind and production asset builds. A
Docker job builds and inspects the production image and checks its health
endpoint.

**Why not quote the test count?**

Counts become stale and say little about risk coverage. The current commit and
CI run are the proper source for exact results.

## Deployment and operations

**Is the application deployed?**

No permanent public deployment is guaranteed. The repository has production
configuration, operational runbooks, CI, and Docker verification; live demos
are temporary and isolated.

**What is required for a production-like environment?**

PostgreSQL, private S3-compatible storage, SMTP, cache/queue, encryption keys,
a malware scanner, TLS/domain configuration, secrets, workers/scheduler,
monitoring, backups, and market-specific operational review.

**How do health checks differ?**

The application exposes health/readiness behavior for process and dependency
visibility while avoiding sensitive diagnostics in public responses. Job
heartbeats and integrity checks provide separate operational evidence.

**How are failures observed?**

Structured logging, email-delivery records, job status/heartbeats, security
events, readiness checks, an operations dashboard, and a provider-neutral error
reporter provide inspectable signals.

**What production evidence is missing?**

There is no claimed traffic history, capacity result at production scale,
configured permanent provider stack, uptime record, or completed regulatory and
accessibility review.

## Trade-offs

**What would you change first for a real client?**

Confirm the target market, pharmacy operating model, data/privacy obligations,
roles, payment and delivery providers, recovery objectives, and acceptance
criteria. Those decisions come before adding roadmap modules.

**What is the largest current product limitation?**

The globally scoped single-pharmacy model. Multi-branch and tenancy affect most
ownership, inventory, reporting, and authorization queries and cannot be added
as a superficial flag.

**What is intentionally simple?**

Payment is cash on delivery, stock is product-level rather than lot-level, and
states use explicit maps rather than a state-machine dependency. These choices
keep the implemented boundary inspectable while leaving known extensions clear.

**What was the hardest conceptual distinction?**

Separating a stock commitment from a physical stock event. That distinction
drives reservation, consumption, cancellation, movement, and availability
behavior across the application.

**What did the demo work teach?**

A repeatable demo needs stable business identifiers, coherent historical
states, safe environment checks, normal authorization, and explicit operator
cleanup. Random seed records are not enough to explain a connected workflow.

**What should not be inferred from the portfolio?**

Real client results, medical decision support, compliance certification,
production scale, permanent hosting, or support for roadmap modules and
unconfigured external integrations.

