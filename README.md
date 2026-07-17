# Saydaliyati — Arabic RTL Pharmacy Commerce and Operations

Saydaliyati (صيدليتي) is a Ruby on Rails application that connects an Arabic
right-to-left customer storefront with prescription review, stock reservation,
order fulfilment, delivery operations, promotions, reporting, and pharmacy
administration.

The repository is a software engineering portfolio project and supports
temporary, on-request demonstrations. A permanently available public deployment
is not guaranteed. The customer and pharmacy workflows are implemented through
Phase 15; supplier, purchasing, and later advanced modules remain roadmap work.

## Capabilities

### Customer commerce

- Arabic RTL catalog, search, filters, product details, guest and account carts.
- Wishlist, saved addresses, delivery-zone matching, scheduled delivery slots,
  coupon application, cash-on-delivery checkout, and customer order history.
- Immutable product, price, customer, address, promotion, and delivery snapshots
  on submitted orders.

### Prescriptions and pharmacy operations

- Prescription-required products, controlled image/PDF upload, signature
  validation, asynchronous malware scanning, and private authorized downloads.
- Pharmacist review states, safe customer follow-ups, approval/rejection, and
  integration with order and reservation state.
- Order queues, explicit transitions, fulfilment assignment, picking, packing,
  dispatch, delivery, cancellation, and customer notifications.

### Inventory, delivery, and promotions

- Locked stock adjustments, append-only inventory movements, stock reservations,
  expiry, consumption, release, and return-to-stock operations.
- Delivery zones, methods, fees, minimums, capacity-controlled slots, and
  fulfilment records.
- Product, category, brand, cart, and delivery promotions; coupons, limits,
  deterministic calculation, redemption, release, and audit history.

### Administration and reporting

- Catalog, price, inventory, user/role, invitation, pharmacy-setting, promotion,
  coupon, and delivery administration.
- Role-scoped sales, order, product, inventory, promotion, customer,
  prescription, and fulfilment reports.
- Formula-safe CSV output and private asynchronous report exports with expiry,
  ownership checks, status tracking, and notification.

### Security and operations

- Devise authentication, account locking, invitations, session-version
  invalidation, and TOTP 2FA with single-use recovery codes for privileged roles.
- Server-side role authorization, Rack::Attack throttling, CSP/security headers,
  sensitive-parameter filtering, security events, and an operations dashboard.
- Solid Queue, recurring jobs, Solid Cache, health/readiness checks, structured
  logging, email-delivery tracking, integrity checks, and provider-neutral error
  reporting.

### Demo tooling

- Explicit demo mode, deterministic and repeatable fictional data, protected demo
  identities, stable business identifiers, and role-aware guided journeys.
- An authenticated `/demo` control center plus operator and presentation guides.

## Roles

| Role | Responsibility |
| --- | --- |
| Customer | Browse, manage a cart and wishlist, checkout, upload a required prescription, and view owned orders. |
| Pharmacist | Review authorized prescription records and prescription reporting without inventory cost access. |
| Order manager | Operate orders, fulfilment, delivery zones/slots, and operational reports without prescription-file access. |
| Inventory manager | Manage catalog, prices, stock, movements, and inventory reports without medical-data access. |
| Administrator | Manage users, settings, promotions, reporting, and security/operations oversight. |

Privileged roles use normal password authentication followed by TOTP. Demo
credentials and TOTP secrets are never published in this repository's guides.

## Connected workflow

```text
Catalog → Cart → Checkout → Inventory reservation
                           ├─ ordinary order → confirmation
                           └─ prescription order → scan → pharmacist review
                                                ├─ approve → order progression
                                                └─ reject → reservation release

confirmation → preparation → reservation consumption → dispatch → delivery
cancellation/rejection → reservation and eligible promotion release
all completed activity → role-scoped reports and operational audit records
```

Checkout locks relevant rows, snapshots commercial data, and creates the order,
items, reservations, address, fulfilment, promotion records, and prescription
inside a transaction. See [Architecture](docs/architecture.md) for details.

## Technical stack

- Ruby 3.4.6 and Rails 8.1.3
- PostgreSQL
- Hotwire: Turbo, Stimulus, and Importmap
- Tailwind CSS
- Devise, ROTP, and QR provisioning for authentication and TOTP
- Active Storage with private S3-compatible production storage
- Solid Queue and Solid Cache
- Pagy, Rack::Attack, image_processing/libvips, and ClamAV integration boundary
- Minitest, Capybara/Selenium, RuboCop, Brakeman, and bundler-audit

## Architecture highlights

The application is a Rails modular monolith: controllers handle HTTP and
authorization boundaries, while focused service objects own commercial state
transitions. PostgreSQL transactions, row locks, uniqueness constraints,
optimistic locking, idempotency keys, immutable movement records, and order
snapshots protect critical workflows.

The frontend remains server-rendered and progressively enhanced with Hotwire.
Background work handles mail, scans, exports, reservation expiry, invitation
expiry, and cleanup. Production boundaries are configured for private object
storage, SMTP, ClamAV, and optional external error reporting.

See the [architecture overview](docs/architecture.md), [feature matrix](docs/feature_matrix.md),
and [technical reviewer guide](docs/reviewer_guide.md).

## Security and integrity scope

Verified controls include encrypted TOTP secrets, digested recovery codes,
session invalidation after sensitive identity changes, scoped record loading,
private prescription/export routes, upload allowlists and magic-byte checks,
fail-closed scan states, rate limits, CSRF protection, CSP/security headers,
append-only security and inventory records, and integrity checks.

These controls reduce risk; they do not constitute a security certification or
legal, pharmacy, privacy, HIPAA, GDPR, or PCI compliance determination.

## Demo experience

The on-request demo uses fictional Arabic data and guided accounts for all five
roles. It preserves normal passwords, TOTP, sessions, and authorization—there is
no demo authentication bypass or impersonation. The `/demo` page enables only
links authorized for the signed-in role.

A remote demo must use an isolated database, private bucket, SMTP sandbox,
cache/queue, encryption keys, and scanner. It performs no real card payment,
SMS, courier operation, or medical decision. Start with the [demo-mode guide](docs/demo_mode.md)
and [operator checklist](docs/demo_operator_checklist.md).

## Screenshots

Screenshots will be captured from the deterministic demo dataset in a later
visual phase. Until then, the repository keeps a non-breaking
[screenshot plan](docs/screenshot_plan.md) covering desktop, mobile, customer,
staff, and administration views; no placeholder image URLs are embedded here.

## Local setup

Prerequisites:

- Ruby 3.4.6 with Bundler
- PostgreSQL
- libvips (for image variants)

```bash
git clone <repository-url>
cd clinic
bin/setup
bin/dev
```

`bin/setup` installs the bundle and runs `bin/rails db:prepare`. `bin/dev`
starts Rails and the Tailwind watcher through Foreman on port 3000 by default.
Local PostgreSQL connection settings can be supplied with `POSTGRES_USER`,
`POSTGRES_PASSWORD`, and `POSTGRES_HOST`; never reuse production credentials.

## Docker

The checked Dockerfile is a production-image and CI verification path, not a
complete local-development stack. It uses a multi-stage build, precompiles
assets, omits development/test gems, includes PostgreSQL/libvips runtime
packages, runs as a non-root user, and exposes `/up` as its health check.

```bash
docker build -t saydaliyati .
```

Running the image requires the production configuration documented in
[environment variables](docs/environment_variables.md). Do not point a local
container at real production services.

## Demo setup

Enable demo mode only against an isolated demo database and storage service:

```bash
DEMO_MODE=true bin/rails demo:seed
```

Non-development environments also require configured demo passwords, a TOTP
seed, and explicit isolated-storage confirmation. Variable names and safety
requirements are documented in [Demo mode](docs/demo_mode.md) and
[Environment variables](docs/environment_variables.md). Do not place passwords
or TOTP values in shell history, source control, or public documentation.

## Tests and quality checks

```bash
bin/rails db:test:prepare
bin/rails test
bin/rails test:system
bin/rubocop
bundle exec brakeman -q
bundle audit check
bin/importmap audit
bin/rails zeitwerk:check
bin/rails tailwindcss:build
```

GitHub Actions also builds and inspects the production Docker image, checks the
container health endpoint, verifies production eager loading/assets, and runs
the test and audit jobs against PostgreSQL.

## Documentation

- [Architecture](docs/architecture.md)
- [Portfolio engineering case study](docs/portfolio_case_study.md)
- [Feature matrix and roadmap](docs/feature_matrix.md)
- [Technical reviewer guide](docs/reviewer_guide.md)
- [Screenshot plan](docs/screenshot_plan.md)
- [Demo mode](docs/demo_mode.md) and [demo operator checklist](docs/demo_operator_checklist.md)
- [Production readiness](docs/production_readiness.md)
- [Security operations](docs/security_operations.md)
- [Environment variables](docs/environment_variables.md)

## Roadmap: Phases 16–27

1. Suppliers and Purchasing
2. Batch, Lot, Expiry, and FEFO
3. Pharmacy POS
4. Per-Item Prescription Review and Substitution
5. Drug Safety Rules Engine
6. Advanced Arabic Search
7. Returns and Reverse Logistics
8. Loyalty and Wallet
9. Multi-Branch Operations
10. SaaS Multi-Tenancy
11. APIs and Integrations
12. Advanced Analytics

These are planned modules, not current capabilities.

## Disclaimer

All demo people, addresses, prescriptions, and transactions are fictional. The
application does not provide medical advice. Prescription decisions in a real
operation require appropriately licensed pharmacy professionals. This
repository demonstrates software engineering and product workflow design; it
is not a medical, legal, or regulatory certification.
