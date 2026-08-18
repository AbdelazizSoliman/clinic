# Feature matrix

| Phase 18 capability | Status |
| --- | --- |
| Cashier sessions and reconciliation | Complete |
| Arabic RTL cart and barcode/SKU search | Complete |
| Batch FEFO counter-sale completion | Complete |
| Pharmacist approval and controlled discount | Complete |
| Cash/external-terminal marker and printable receipt | Complete |
| POS reports, CSV and deterministic demo | Complete |
| Per-item review and therapeutic substitution | Complete (Phase 19) |
| Returns/refunds | Deferred (Phase 22) |

| Phase 19 capability | Status |
| --- | --- |
| Per-line pending/under_review/approved/substituted/rejected lifecycle | Complete |
| Pharmacist-only clinical decisions with optimistic locking | Complete |
| Therapeutic substitution with FEFO reallocation | Complete |
| Mixed online-order settlement (ordinary + approved + rejected) | Complete |
| POS line-level review, substitution and idempotent completion | Complete |
| Clinical traceability and immutable decision history | Complete |
| Per-item reports (status, substitution frequency, pharmacist workload) and CSV | Complete |
| Deterministic demo scenarios (new/review/approved/rejected/substituted/mixed/POS) | Complete |

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
| Prescriptions | Required-product upload, states, follow-up, per-item pharmacist review and substitution | Demo-ready | Customer, pharmacist | `Prescription`, `PrescriptionReview`, `Prescriptions::DecideLine`, staff tests |
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
| Suppliers | Stable codes, active history, contact/terms, search and safe deletion | Demo-ready | Inventory manager, admin | `Supplier`, admin supplier workflow/tests |
| Purchasing | Draft/submission/admin approval, immutable lines, partial receipts, cancellation/closure | Demo-ready | Inventory manager, admin | `Purchasing::*`, purchase and authorization tests |
| Purchase inventory | Idempotent receipt movements, outstanding quantities and cost history | Demo-ready | Inventory manager, admin | `PurchaseReceipt*`, `purchase_received`, receiving tests |
| Purchasing reports | Supplier totals, outstanding/overdue, top products, latest costs and CSV | Demo-ready | Inventory manager, admin | `Reports::PurchasingSummary`, report tests |
| Batch inventory and FEFO | Receipt batches, expiry/quarantine, multi-batch reservations, traced consumption, valuation and CSV | Demo-ready | Inventory manager, admin | `InventoryBatch`, `Inventory::AllocateFefo`, batch tests |
| Lots, batches, expiry, FEFO | Lot-level stock and expiry-aware allocation | Planned | — | Phase 17 |
| Pharmacy POS | Counter sales and shift/cash workflow | Demo-ready | Pharmacist, order manager, admin | Phase 18 |
| Per-item prescription review | Item decisions and therapeutic substitution workflow | Demo-ready | Pharmacist | `PrescriptionReview`, `Prescriptions::DecideLine`, Phase 19 |
| Drug safety rules | Versioned local rules for interaction, duplicate therapy, allergy, age, pregnancy/lactation and contraindication; pharmacist acknowledgement, documented override, blocking gate, reports and CSV | Demo-ready | Pharmacist (clinical), admin (rules) | `DrugSafety::*`, `DrugSafetyRule`, Phase 20 |
| Renal/hepatic and dose-limit rules | Needs structured clinical status and structured dose data that the application does not store | Planned | — | Phase 21+ |
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
