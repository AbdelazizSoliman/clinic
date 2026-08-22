# SaaS multi-tenancy

`Organization` is the security root: organization → branches → operational records. Forward migrations create `DEFAULT`, backfill historical rows, add non-null ownership, and enforce critical organization/parent pairs with composite foreign keys. `Current.organization`, `Current.branch`, and optional report `Current.branch_scope` are established per request and reset afterward. Tenant-sensitive jobs serialize organization ID and establish the same context explicitly.

## Ownership classification

Global/platform records are `Organization`, Active Storage metadata, Solid Queue/Cache infrastructure, and `JobHeartbeat`. Everything below is tenant-owned:

- identity and configuration: users, branch memberships, branches, pharmacy settings, delivery zones, promotions, coupons;
- catalog/search: products, brands, categories, active ingredients, product ingredients, search synonyms and events;
- commerce/clinical: carts, orders/items/events, prescriptions/reviews/items/substitutions, safety rules/evaluations/findings;
- inventory/operations: batches, reservations/allocations, movements, transfers/items/allocations, suppliers, purchase orders/items/receipts/items;
- POS/returns/finance: cashier sessions, POS sales/items/payments, return requests/items/inspections/refunds, loyalty and wallet accounts/ledger entries;
- reporting/integrations: report export events, API clients/tokens/idempotency records, webhook endpoints/deliveries, integration audit events, security events and notifications.

Active ingredients and safety definitions are intentionally tenant-owned; there is no premature global drug master. Users primarily belong to one organization. Email remains globally unique because login currently has no tenant selector.

Central default scoping prevents tenant-owned reads from becoming global when request context is absent. Controllers resolve IDs through scoped associations; services call `Operations::TenantGuard` before side effects; generic model validation rejects mismatched tenant associations. Composite database constraints cover critical branch/product/order/POS/purchasing/financial relationships. Polymorphic source links are protected by model/service checks and the read-only integrity audit because PostgreSQL cannot express a practical composite FK across multiple source tables.

`PharmacySetting` is one row per organization. Tenant catalog/configuration codes are unique per organization. Search, reports, finance and clinical operations are scoped at both query and authorization boundaries.

Read-only checks are available as `bin/rails integrity:tenants`, `integrity:inventory`, and `integrity:financial`; they report violations, exit unsuccessfully when found, and never mutate data.
