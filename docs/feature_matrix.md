# Feature matrix

This matrix is the canonical Release 1.0 truth set for buyer-facing,
portfolio-facing, demo-facing, and interview-facing documentation. Historical
phase evidence remains useful only when it is labeled with its date or commit.

Release 1.0 is an Arabic RTL pharmacy commerce and operations application with
application-level organization tenancy and multi-branch operations. It is not a
complete commercial SaaS control plane or a certified production deployment.

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
| Batch/lot inventory and FEFO | Branch-local receipt batches, lot/expiry/quarantine state, multi-batch reservations, deterministic FEFO, traced consumption, valuation and CSV | Demo-ready | Inventory manager, admin | `InventoryBatch`, `Inventory::AllocateFefo`, batch tests |
| Pharmacy POS | Counter sales, cashier sessions, cash reconciliation, wallet and manual external-terminal markers, receipts and reports | Demo-ready | Pharmacist, order manager, admin | `Pos::*`, POS request/service/report tests |
| Per-item prescription review | Item decisions and therapeutic substitution workflow | Demo-ready | Pharmacist | `PrescriptionReview`, `Prescriptions::DecideLine`, Phase 19 |
| Drug safety rules | Versioned local rules for interaction, duplicate therapy, allergy, age, pregnancy/lactation and contraindication; pharmacist acknowledgement, documented override, blocking gate, reports and CSV | Demo-ready | Pharmacist (clinical), admin (rules) | `DrugSafety::*`, `DrugSafetyRule`, Phase 20 |
| Renal/hepatic and dose-limit rules | Needs structured clinical status and structured dose data that the application does not store | Planned | — | Phase 21+ |
| Advanced Arabic search | Arabic normalization, exact identifier priority, token and ingredient matching, typo tolerance, suggestions, synonyms and search reports | Demo-ready | All roles | `Search::*`, pg_trgm, Phase 21 |
| Transliteration and stemming | Latin↔Arabic transliteration, root/stem matching | Planned | — | Phase 22+ |
| Customer/POS sales returns | Partial-quantity returns against immutable online/POS sources, batch-traced inspection/disposition, refund records, receipts and reports | Demo-ready | Customer, staff | `Returns::*`, return request/service tests; no supplier-return workflow |
| Loyalty and wallet | Configurable points, expiry/reversal, monetary wallet, immutable ledgers and online/identified-POS use | Demo-ready | Customer, staff | `Loyalty::*`, `Wallet::*`, ledger tests |
| Multi-branch operations | Authorized branch switching, branch-local stock/FEFO, fulfilment, POS, purchasing, returns, reports and batch-aware transfers | Demo-ready | Staff, admin | Branch/transfer services and isolation tests |
| Application-level organization tenancy | Organization isolation for operational data, configuration, credentials, jobs, reports/search and integrity audits | Demo-ready | Tenant roles | Tenant controller/service/job isolation tests |
| Scoped integration API | Hashed scoped credentials; catalog, branch, inventory and order reads; order cancellation; purchasing/return reads; rate limits and idempotency where applicable | Implemented | Integration clients | `/api/v1`, API request tests |
| Signed outbound webhooks | Tenant-configured HTTPS endpoints, display-once secrets, HMAC signatures, retry state and selected order/inventory/return/purchasing events | Implemented | Integration clients | `Webhooks::*`, webhook security tests |
| Advanced analytics | Tenant/branch-aware operational and executive analytics with bounded date ranges and formula-safe CSV | Demo-ready | Authorized staff | `Analytics::*`, analytics request/service tests |

“Partial” does not mean unsafe fallback behavior is enabled. Production-like
email, storage, scanner, and external error reporting remain disabled or
fail-closed until an operator supplies and verifies isolated services.

## Release 1.0 commercial and validation boundary

The following are not Release 1.0 capabilities or certifications:

- a platform-super-admin tenant-provisioning workflow, self-service tenant
  onboarding, subscription billing, plan enforcement, or production tenant
  validation;
- a real online payment gateway or execution of external-card payments/refunds;
- SMS, WhatsApp, courier, ERP, supplier-API, or other provider-specific
  integrations;
- supplier returns, supplier invoices/payments, or accounting/ERP settlement;
- an external certified clinical knowledge provider, diagnosis, prescribing, or
  replacement of pharmacist judgment;
- regulatory, HIPAA, GDPR, PCI, accessibility, penetration-test,
  production-scale, or uptime certification;
- a permanent validated public demo or committed browser/system scenarios; and
- verified production SMTP, storage, scanning, monitoring, backups, or webhook
  consumers. The repository contains boundaries and runbooks for these services,
  but operators must configure and validate them in their own environment.
