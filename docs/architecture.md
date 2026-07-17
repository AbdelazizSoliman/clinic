# Architecture overview

## System context

Saydaliyati serves five authenticated roles through one Arabic RTL web
application:

- Customers browse products, manage carts/addresses, submit orders and required
  prescription files, and view only their own records.
- Pharmacists review scanned prescriptions and prescription reporting.
- Order managers operate order, delivery, and fulfilment queues.
- Inventory managers maintain catalog, pricing, stock, and inventory reporting.
- Administrators manage identity, settings, promotions, reporting, and security
  operations.

External boundaries are PostgreSQL, private object storage, SMTP, ClamAV (or a
future scanner adapter), and an optional error-reporting adapter. No payment,
SMS, courier, supplier, or clinical decision API is integrated.

The maintainable system diagram is in
[`diagrams/system_context.mmd`](diagrams/system_context.mmd).

## Application style

The application is a Rails modular monolith. It deploys one codebase with web
and worker processes rather than splitting commercial transactions across
services. PostgreSQL is the source of truth for business state, Solid Queue,
and Solid Cache. Server-rendered HTML is progressively enhanced with Turbo and
Stimulus; Tailwind provides the Arabic RTL responsive interface.

Controllers enforce authentication and role boundaries. Models hold
associations, validations, state definitions, and local invariants. Service
objects own multi-record transitions and transaction boundaries. Active Job
executes mail delivery, malware scanning, exports, reservation/invitation
expiry, and cleanup. Active Storage uses local isolated storage in development
and private S3-compatible storage in production configuration.

## Major domains

### Identity and access

`User` uses Devise for password authentication, recovery, remember-me, and
locking. Roles are `customer`, `pharmacist`, `order_manager`,
`inventory_manager`, and `admin`. Capability methods express the server-side
role matrix used by controllers and services.

Privileged roles require TOTP enrollment. The TOTP secret is encrypted through
Active Record encryption; recovery codes are stored as digests and consumed
once. A monotonically increasing `session_version` invalidates older sessions
after password, role, active-state, or 2FA changes. Invitations and role/user
administration record audit and security events.

### Catalog

`Category`, `Brand`, `Product`, `ProductImage`, and `ProductPriceChange` model
the public catalog and administrative history. Product slugs are stable public
identifiers. Availability subtracts active reservations from physical stock.
Image variants are predefined; prescription images are not public catalog
assets.

### Cart and checkout

`Cart` and `CartItem` support authenticated and guest ownership. Cart resolution
and merge services preserve a single active shopping context. Checkout validates
the authenticated address, delivery-zone/method match, slot availability,
coupon eligibility, stock, and prescription attachments.

`Orders::CreateFromCart` uses a submission token for idempotency. In one database
transaction it locks the cart, products, relevant promotion records, and any
scheduled slot; recalculates prices; creates the order and immutable snapshots;
creates stock reservations and promotion/redemption records; and completes the
cart.

### Prescriptions

`Prescription` belongs to both the customer and order and supports submitted,
under-review, approved, partially approved, and rejected states. Attachments
accept bounded JPEG, PNG, WebP, and PDF files. Extension/MIME validation is
supplemented by bounded magic-byte inspection.

Creation enqueues `ScanPrescriptionJob`. The `Uploads::Scanner` boundary can
use ClamAV; pending, failed, and infected states remain unavailable for normal
staff review. `Prescriptions::Review` checks pharmacist/admin authorization,
scan state, row version, and allowed transitions. Final decisions update the
order/reservation workflow and notify the customer after the transactional
change.

### Orders

`Order`, `OrderItem`, `OrderAddress`, `OrderEvent`, and `OrderPromotion` preserve
the submitted commercial context. Order items retain product/category/brand and
price fields; the order retains customer, delivery, promotion, fee, and total
snapshots. The model validates that total components agree.

`Orders::Transition` allows explicit state edges rather than arbitrary status
updates. It locks the order, honors optimistic `lock_version`, consumes
reservations when the order becomes ready, and records customer-visible and
internal events. `Orders::Cancel` authorizes customer/staff/system cancellation,
releases reservations and eligible promotion redemptions, and is safe to repeat
for an already-cancelled order.

### Inventory

`Product#stock_quantity` is physical stock. `InventoryReservation` records
active, released, or consumed quantities for one order item. Available-to-sell
stock is physical stock minus active reservations.

`Inventory::AdjustStock` locks the product and prevents reductions below active
reservations or below zero. Each accepted adjustment creates an
`InventoryMovement` whose before/delta/after values must reconcile. Movement
records abort updates and deletion. Consumption locks products and reservations,
decrements physical stock, and creates idempotent movement records; release
changes reservation state without inventing stock. Expiry, extension, release,
consumption, and return-to-stock are separate operations.

See [`diagrams/order_inventory_flow.mmd`](diagrams/order_inventory_flow.mmd).

### Fulfilment and delivery

`DeliveryZone`, `DeliveryMethod`, `DeliverySlot`, and zone districts determine
coverage, fees, minimums, available methods, and scheduled capacity.
`Fulfilment` is a one-to-one operational record for an order. Assignment and
update services enforce order-manager/admin capabilities and state transitions
through picking, packing, dispatch, and delivery.

### Promotions

Promotions can target products, categories, brands, carts, or delivery and may
use percentage, fixed-amount, fixed-price, or free-delivery calculations where
compatible. Eligibility and calculation services apply schedules, exclusions,
minimums, usage limits, priority, and stacking policy. Checkout locks promotion
records before recording snapshots and redemptions. Cancellation/rejection can
release eligible redemptions.

### Reporting

Report services calculate sales, orders, products, inventory, promotions,
customers, prescriptions, and fulfilment views over bounded date ranges.
Authorization varies by role. CSV cells are protected from spreadsheet formula
injection. Large or requested exports use `ReportExport`, Solid Queue, a private
Active Storage attachment, deduplication, concurrency limits, expiry, and an
authorized application download route.

### Operations and notifications

Notifications, transactional email-delivery records, security events, job
heartbeats, integrity checks, health/readiness endpoints, maintenance mode, and
the admin security dashboard provide operational visibility. Error reporting is
adapter-based and must not crash application requests when its provider fails.

### Demo tooling

`DemoMode.enabled?` is the centralized environment switch.
`DemoMode::SafetyPolicy` protects explicitly configured demo actions and stable
demo identities without changing normal behavior. `DemoData::Seeder` creates a
deterministic fictional graph and returns a typed manifest; it refuses unsafe
execution and suppresses external job execution during seeding.

`DemoGuidance::JourneyCatalog` defines role journeys. `ScenarioResolver` looks
up stable order numbers, slugs, promotion references, and role capabilities at
request time, avoiding hard-coded primary keys and unauthorized direct links.

## Data-flow examples

### Ordinary order

1. The customer resolves an active cart and chooses an owned active address.
2. Checkout matches a delivery zone/method and validates any scheduled slot.
3. The order service locks cart, products, slot, promotion, and coupon rows.
4. Prices are recalculated and immutable order/item/address/promotion snapshots
   are created with active inventory reservations.
5. An order manager confirms and prepares the order.
6. Moving to ready-for-delivery consumes reservations and records stock
   movements; fulfilment then progresses to dispatch and delivery.

### Prescription-required order

1. Checkout validates one to five bounded supported files before creating an
   order in `pending_prescription` with reservations.
2. Creation enqueues malware scanning; staff access is denied until clean.
3. A pharmacist reviews the clean prescription using allowed state transitions.
4. Approval permits the order workflow to continue. Rejection records a safe
   reason, rejects the order, and releases reservations/redemptions.

### Reservation consumption

At the ready-for-delivery transition, the consumption service locks relevant
products and reservations in deterministic order. It verifies sufficient
physical stock, decrements each product, marks each reservation consumed, and
creates one idempotent append-only movement per reservation inside a transaction.

### Cancellation or rejection

An authorized cancellation/rejection locks the order and checks the current
state and optimistic version. Active reservations become released; consumed
reservations prevent unsafe cancellation. Eligible promotion redemptions are
released and the action is recorded as an order event.

### Demo seed and guide

The explicit `demo:seed` task checks demo mode and isolation requirements, uses
stable emails/slugs/SKUs/order numbers/codes, and updates or reuses records on a
second run. The guide later resolves those business identifiers under the
current user's normal authorization. No password, TOTP bypass, impersonation,
or global database reset is introduced.

## Transaction and consistency boundaries

- Checkout and order creation are atomic and idempotent by submission token.
- Product, order, reservation, slot, promotion, and coupon rows are locked where
  concurrent decisions affect stock, capacity, usage, or state.
- Database uniqueness constraints protect order numbers, one reservation per
  order item, one fulfilment per order, movement idempotency keys, export
  deduplication, and other stable identities.
- Optimistic locking rejects stale administrative and operational updates.
- Order totals and movement arithmetic are model invariants.
- Inventory movements are append-only; order snapshots are not recomputed from
  mutable catalog/settings data.
- Recurring expiry and cleanup work is designed to be safe under repetition and
  exposes job heartbeats.

## Security boundaries

- Devise establishes authentication; controllers and services independently
  check ownership/capabilities.
- Privileged access requires enrolled TOTP and current sessions are bound to the
  user's `session_version`.
- Prescription files and report exports use authorized application routes and
  private storage rather than public object URLs.
- Upload allowlists, signature validation, ClamAV adapter timeouts, scan states,
  and fail-closed access form the file boundary. A real scanner must still be
  configured and monitored by the operator.
- Active Job separates email, scan, and export failures from completed business
  transactions while preserving delivery/job observability.
- Demo mode does not make shared services safe; its policy and seed checks assume
  an isolated environment.

## Current limitations

- One globally scoped pharmacy; no multi-branch or multi-tenant boundary.
- Cash on delivery is the only operational payment method.
- No supplier, purchasing, batch/lot, expiry, FEFO, or POS module.
- No per-item substitution workflow or drug-safety rules engine.
- No SMS, courier, payment-gateway, or public API integration.
- No permanent public demo is guaranteed.
- Technical safeguards do not establish medical, privacy, or regulatory
  compliance.

For implementation status and planned phases, see the
[feature matrix](feature_matrix.md).
