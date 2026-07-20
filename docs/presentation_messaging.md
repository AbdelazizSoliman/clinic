# Presentation messaging

This document is the canonical source for short descriptions and portfolio
positioning. It is grounded in the [feature matrix](feature_matrix.md),
[architecture](architecture.md), and [engineering case study](portfolio_case_study.md).

## Repository discovery

### Source summary

- The [README](../README.md) gives the broadest introduction: current
  capabilities, roles, connected workflow, stack, screenshots, setup, and the
  Phase 16–27 roadmap.
- The [engineering case study](portfolio_case_study.md) explains the product
  problem, important design decisions, engineering outcomes, and limitations.
- The [technical reviewer guide](reviewer_guide.md) maps high-value claims to
  concrete services, models, controllers, tests, and operational files.
- The [visual gallery](visual_gallery.md) contains 21 reviewed real-browser
  captures made with deterministic fictional data.
- The [screenshot plan](screenshot_plan.md) records stable scenarios, roles,
  viewports, sanitization rules, and capture verification.
- The roadmap is stated in the README and [feature matrix](feature_matrix.md),
  which distinguishes implemented, demo-ready, partial, and planned work.
- The [architecture overview](architecture.md) documents the modular monolith,
  domain and external boundaries, data flows, consistency mechanisms, security,
  and current limitations.
- The [demo-mode guide](demo_mode.md), [operator checklist](demo_operator_checklist.md),
  and [presentation script](demo_presentation_script.md) cover deterministic
  seeding, normal role-based authentication, temporary access, and safe tours.

### Strongest engineering differentiators

1. One transactional workflow connects checkout, immutable commercial
   snapshots, stock reservations, prescriptions, fulfilment, and promotion
   records.
2. Inventory distinguishes physical, reserved, and available quantities;
   consumption creates append-only arithmetically validated movements, while
   cancellation releases unconsumed reservations.
3. Private prescription handling combines bounded type/signature validation,
   fail-closed scan states, authorized downloads, and role-scoped review.
4. Server-side role boundaries separate medical, inventory-cost, order, and
   administrative access. Privileged roles retain normal password and TOTP 2FA
   in demo mode.
5. A Rails modular monolith keeps cross-domain transactions local. Explicit
   service objects, locks, constraints, optimistic versions, and idempotency
   keys make important state changes inspectable and testable.
6. Deterministic fictional demo data and stable business identifiers make
   complex states repeatable without a login bypass or real personal data.

### Strongest business differentiators

1. A complete Arabic RTL journey covers both customer commerce and internal
   pharmacy operations instead of presenting disconnected administration CRUD.
2. Prescription review, stock commitment, order preparation, dispatch, and
   reporting share the same order history and state model.
3. Role-specific workspaces let each staff function see the information needed
   for its task without giving every employee broad access.
4. Delivery coverage, fees, scheduled capacity, coupons, and promotion limits
   are validated as part of checkout and retained in order history.
5. The guided demo can show coherent fulfilled, pending, rejected, cancelled,
   low-stock, and reporting scenarios on request.

### Current limitations and claims to avoid

- The application is globally scoped to one pharmacy. Multi-branch operation
  and SaaS tenancy are roadmap items.
- Cash on delivery is the only operational payment method. No payment gateway,
  SMS, courier, ERP, WhatsApp, or public API is integrated.
- Suppliers, purchasing, lots/batches, expiry-aware FEFO, POS, per-item
  substitution, drug-safety rules, returns, loyalty, and advanced analytics are
  not implemented.
- Email tracking, private production storage configuration, malware-scanner
  adapters, and error-reporting boundaries exist, but real services require
  operator configuration and verification.
- There is no permanent public deployment. Demonstrations are temporary,
  isolated, and arranged on request.
- Do not claim real-client adoption, revenue, conversion, production traffic,
  performance at scale, regulatory compliance, formal accessibility
  conformance, or medical decision support.

### Best external screenshots

The highest-signal captures are the Arabic storefront, cart and coupon,
pharmacist review, fulfilment workflow, inventory dashboard, reports dashboard,
guided demo center, and mobile storefront. See the ranked and platform-specific
[screenshot selection](screenshot_selection.md).

## Elevator pitches

### 15 seconds — recruiter

Saydaliyati is a Rails 8 portfolio application that connects an Arabic RTL
pharmacy storefront to prescription review, inventory reservations, fulfilment,
and reporting. It demonstrates secure role-based workflows, transactional
integrity, Hotwire, PostgreSQL, and a repeatable on-request demo.

### 30 seconds — engineering manager

Saydaliyati is a Rails modular monolith built around the difficult parts of an
online pharmacy workflow, not just its catalog. Checkout snapshots commercial
history and reserves stock atomically; private prescriptions pass through
fail-closed scanning and pharmacist review; fulfilment consumes reservations
into append-only stock movements. The Arabic RTL interface uses Hotwire and
Tailwind, while role boundaries, TOTP, tests, CI, and deterministic demo data
make the implementation reviewable end to end.

### 60 seconds — non-technical client

Saydaliyati demonstrates how an Arabic online pharmacy and its internal team
could work in one system. Customers can browse in a right-to-left interface,
use a cart and coupon, choose delivery, place cash-on-delivery orders, and
submit a prescription when a product requires one. Pharmacists receive a
focused review queue, order staff manage preparation and delivery stages,
inventory staff can distinguish stock on hand from stock already reserved, and
administrators can manage promotions, users, and reports. The project includes
a safe fictional dataset and a guided environment for temporary live
demonstrations. It currently represents one pharmacy and does not yet include
online payment, suppliers, branches, loyalty, or external integrations; those
would be separate extensions.

## Project summaries

### Short summary

Saydaliyati is an Arabic RTL online-pharmacy and operations portfolio project
built with Ruby on Rails 8, PostgreSQL, Hotwire, Stimulus, and Tailwind CSS. It
connects the customer journey—catalog, search, cart, coupon, delivery selection,
cash-on-delivery checkout, and order history—to prescription review, inventory
reservations, fulfilment, promotions, reporting, and administration.

The engineering emphasis is on trustworthy workflow boundaries. Checkout uses
transactions and row locks, submitted orders retain immutable commercial
snapshots, and stock is represented as physical, reserved, and available before
append-only movements record consumption. Private prescription access is
role-scoped and gated by validation and scan state. Privileged roles use TOTP
2FA. A deterministic fictional dataset and role-aware demo center support
repeatable, temporary demonstrations without bypassing authentication. The
current scope is one pharmacy with cash on delivery; external payment,
multi-branch, supplier, lot/FEFO, and public API capabilities remain outside the
implemented product.

### Medium summary

Saydaliyati (صيدليتي) is a professional engineering portfolio project for an
Arabic online pharmacy. Its right-to-left customer experience includes product
discovery, search and filters, wishlist, cart, coupons, saved addresses,
delivery-zone and scheduled-slot selection, cash-on-delivery checkout, and
order history. The same Rails application gives pharmacists, order managers,
inventory managers, and administrators role-specific operational interfaces.

The project is designed around connected workflow integrity. When a customer
checks out, the application recalculates totals and creates the order, items,
commercial snapshots, address, fulfilment, inventory reservations, promotion
records, and any required prescription within a controlled transaction.
Prescription documents use private storage routes, bounded file validation,
scan-state gating, and explicit pharmacist decisions. Inventory does not simply
subtract a number at checkout: it separates physical, reserved, and available
stock, then consumes reservations into append-only movements at the appropriate
order transition. Cancellation or rejection releases commitments that were not
consumed.

Technically, Saydaliyati is a Rails 8 modular monolith backed by PostgreSQL. It
uses server-rendered HTML with Turbo and Stimulus, Tailwind CSS for responsive
Arabic RTL layouts, Solid Queue for background work, and explicit services for
multi-record state changes. Authentication uses Devise, with TOTP 2FA and
single-use recovery codes for privileged roles. Tests cover services, models,
requests, jobs, authorization, concurrency-sensitive workflows, and demo
behavior; CI and Docker configuration provide inspectable build evidence.

Role-scoped reports connect sales, orders, products, inventory, promotions,
customers, prescriptions, and fulfilment. Private asynchronous CSV exports add
ownership revalidation, status tracking, deduplication, concurrency limits, and
expiry without exposing public download URLs.

A deterministic fictional dataset, stable business identifiers, 21 reviewed
browser screenshots, and an authenticated guided-demo center support temporary,
on-request demonstrations. No permanent public deployment is promised. Current
scope is a single pharmacy using cash on delivery; payment gateways, suppliers,
lots and FEFO, POS, branches, tenancy, loyalty, returns, and external APIs are
planned possibilities rather than existing features.

### Long project overview

Saydaliyati (صيدليتي) is an Arabic RTL pharmacy commerce and operations system
built as a Ruby on Rails engineering portfolio. It explores a coordination
problem that is broader than a typical storefront: a customer order may involve
a delivery address, a prescription that must remain private, stock that must be
held while review is pending, promotion and delivery limits, several staff
hand-offs, and a historical record that must remain understandable after the
catalog changes.

The customer-facing workflow includes an Arabic product catalog, search and
filters, product details, wishlist, guest and account carts, coupons, saved
addresses, delivery zones and methods, capacity-controlled scheduled slots,
cash-on-delivery checkout, notifications, and owned order history. Products can
require a prescription. In that case, bounded JPEG, PNG, WebP, or PDF uploads
enter a private workflow with file-signature checks, asynchronous scanner
integration, fail-closed access states, and pharmacist review.

Internal work is divided across five roles. Pharmacists can review authorized
prescription records without receiving inventory-cost access. Order managers
operate order and fulfilment queues without access to prescription files.
Inventory managers maintain catalog, prices, stock, and movement history.
Administrators manage users, pharmacy settings, promotions, reports, and
security operations. These boundaries are enforced on the server; navigation
visibility is not treated as authorization.

The application uses a Rails modular-monolith architecture because checkout and
operational transitions benefit from local transactions across several
domains. Focused service objects own multi-record decisions. PostgreSQL
transactions, deterministic row locking, uniqueness constraints, optimistic
locking, idempotency keys, arithmetic invariants, and immutable order snapshots
protect critical workflows. Inventory is modeled as physical stock minus active
reservations. Moving an order to ready-for-delivery consumes reservations,
decrements physical stock, and writes append-only movements. Rejection or
cancellation releases active reservations instead of adding stock that was
never removed.

The interface is server-rendered and progressively enhanced with Turbo and
Stimulus. Tailwind CSS supports responsive Arabic RTL layouts without a separate
client application. Solid Queue handles mail, prescription scanning, exports,
reservation and invitation expiry, and cleanup. Devise provides authentication;
privileged roles add encrypted TOTP secrets, single-use recovery codes, account
locking, and session invalidation after sensitive changes. Security headers,
rate limiting, parameter filtering, private application download routes, and
operational audit records provide additional defense layers without constituting
a compliance certification.

For evaluation, the repository includes a deterministic fictional demo dataset
covering customer, pharmacist, fulfilment, inventory, promotion, reporting, and
administrative scenarios. Stable business identifiers make the seed repeatable
and the guided `/demo` center resolves links under the signed-in user's normal
permissions. Twenty-one reviewed browser captures document desktop and mobile
views. A temporary demonstration can be arranged in an isolated environment;
there is no permanent public deployment and no authentication shortcut.

The current implementation targets one globally scoped pharmacy and uses cash
on delivery. Real SMTP, private object storage, malware scanning, and external
error reporting require separately configured services. Payment gateways, SMS,
couriers, suppliers and purchasing, lots/batches and FEFO, POS, returns,
loyalty, multi-branch operation, SaaS tenancy, public APIs, and advanced
analytics are not current capabilities. The repository presents them only as
possible roadmap work.

## Portfolio positioning

### Readiness demonstrated

The project is relevant evidence for product companies, consultancies, and
internal engineering teams building workflow-heavy Rails applications,
regulated-data-adjacent products, Arabic/localized commerce, inventory or order
operations, and business systems that need background jobs and role separation.
It also supports conversations with small businesses exploring a custom
commerce-and-operations product, provided the current single-pharmacy boundary
and extension work are explained early.

### Rails skills showcased

- Domain modeling and transactional service objects in a modular monolith.
- Active Record transactions, row and optimistic locking, constraints,
  idempotency, immutable snapshots, and append-only records.
- Devise authentication, TOTP 2FA, role capabilities, ownership scoping, and
  private Active Storage access.
- Turbo and Stimulus enhancement of server-rendered Arabic RTL interfaces.
- Active Job/Solid Queue workflows, report exports, recurring tasks, and
  operational health and integrity checks.
- Minitest across models, services, requests, jobs, authorization, and
  concurrency-sensitive behavior, plus CI and Docker verification.

### Decisions to emphasize

Lead with inventory correctness, commercial snapshots, role isolation, the
prescription file boundary, explicit state transitions, and deterministic demo
architecture. Explain why the modular monolith is appropriate for transactions
that span closely related domains, and why Hotwire avoids duplicating validation
and authorization in a separate client.

### Areas to give less emphasis

Treat basic catalog CRUD, generic framework conventions, badges, and the length
of the feature list as supporting context. Do not center the story on future
modules, deployment configuration, compliance language, or visual polish alone.
The most credible presentation connects a business risk to the implemented
engineering boundary that addresses it.
