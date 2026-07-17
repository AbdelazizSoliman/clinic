# Feature matrix

Status meanings:

- **Implemented** — present in application code and covered by repository tests.
- **Demo-ready** — implemented and represented by deterministic guided data.
- **Partial** — useful foundation exists, but the complete operational boundary
  requires external configuration or later work.
- **Planned** — roadmap only; not a current capability.

| Domain | Capability | Status | Primary roles | Evidence / phase |
| --- | --- | --- | --- | --- |
| Storefront | Arabic RTL catalog, search/filter, product detail, availability | Demo-ready | Customer | `ProductsController`, `ProductsQuery`, storefront tests |
| Customer account | Registration, login, addresses, wishlist, notifications, owned orders | Implemented | Customer | Devise/controllers, ownership request tests |
| Cart and checkout | Guest/account cart, merge, coupon, zone/method/slot, COD checkout | Demo-ready | Customer | `Carts::*`, `Orders::CreateFromCart`, checkout tests |
| Prescriptions | Required-product upload, states, follow-up, pharmacist review | Demo-ready | Customer, pharmacist | `Prescription`, `Prescriptions::Review`, staff tests |
| Upload security | Allowlists, bounded signature validation, private authorized access | Implemented | Customer, pharmacist | `AttachmentValidator`, `FileSignature`, security tests |
| Malware scanning | Fail-closed states and ClamAV adapter boundary | Partial | Pharmacist, admin | `Uploads::Scanner`; real service must be configured |
| Orders | Immutable snapshots, events, authorized transitions and cancellation | Demo-ready | Customer, order manager | `Order`, `Orders::*`, order/staff tests |
| Inventory | Physical stock, reservations, expiry/release/consume, append-only movements | Demo-ready | Inventory manager, order manager | `Inventory::*`, inventory/concurrency tests |
| Fulfilment | Assignment, picking, packing, dispatch, delivery | Demo-ready | Order manager | `Delivery::*`, fulfilment request/service tests |
| Delivery | Zones, district matching, fees, methods, scheduled slot capacity | Demo-ready | Customer, order manager | Delivery models/services and tests |
| Promotions | Product/category/brand/cart/delivery discounts, coupons and limits | Demo-ready | Customer, admin | `Promotions::*`, promotion tests |
| Reports | Role-scoped operational reports and formula-safe CSV | Demo-ready | Privileged roles | `Reports::*`, report controller/service tests |
| Async exports | Private queued exports, deduplication, limits, expiry, download ownership | Implemented | Privileged roles | `ReportExport`, export job/request tests |
| Identity | Invitations, roles, locking, activation, audit history | Implemented | Admin | User administration services/tests |
| Privileged security | TOTP, recovery codes, session versioning, session revocation | Implemented | Privileged roles | `User`, 2FA/session security tests |
| Application security | Rate limits, CSP/headers, CSRF, parameter filtering, security events | Implemented | All/admin | Initializers, security request tests |
| Operations | Solid Queue/Cache, schedules, heartbeats, readiness, integrity checks | Implemented | Admin/operator | Phase 14 services, jobs, operations tests |
| Email | Environment SMTP boundary and durable delivery/retry tracking | Partial | All/admin | Tracking implemented; real SMTP requires configuration |
| Storage | Local dev/test and private S3-compatible production boundary | Partial | All/operator | Configuration implemented; real bucket requires configuration |
| Error reporting | Safe logging adapter and provider-neutral external boundary | Partial | Operator | `Errors::Reporter`; no commercial provider selected |
| Demo | Explicit mode, deterministic data, protected identities, guided journeys | Demo-ready | All roles/operator | `DemoMode`, `DemoData`, `DemoGuidance`, demo docs/tests |
| Suppliers and purchasing | Supplier records, purchase orders, receiving | Planned | — | Phase 16 |
| Lots, batches, expiry, FEFO | Lot-level stock and expiry-aware allocation | Planned | — | Phase 17 |
| Pharmacy POS | Counter sales and shift/cash workflow | Planned | — | Phase 18 |
| Per-item prescription review | Item decisions and substitution workflow | Planned | — | Phase 19 |
| Drug safety rules | Interaction/allergy/rule engine | Planned | — | Phase 20 |
| Advanced Arabic search | Normalization, typo tolerance, richer ranking | Planned | — | Phase 21 |
| Returns | Returns, refunds, reverse inventory/logistics | Planned | — | Phase 22 |
| Loyalty and wallet | Points, credits, wallet ledger | Planned | — | Phase 23 |
| Multi-branch operations | Branch-specific stock and fulfilment | Planned | — | Phase 24 |
| SaaS multi-tenancy | Tenant isolation and subscription operations | Planned | — | Phase 25 |
| APIs and integrations | Public/partner APIs and external providers | Planned | — | Phase 26 |
| Advanced analytics | Deeper operational and commercial analytics | Planned | — | Phase 27 |

“Partial” does not mean unsafe fallback behavior is enabled. Production-like
email, storage, scanner, and external error reporting remain disabled or
fail-closed until an operator supplies and verifies isolated services.
