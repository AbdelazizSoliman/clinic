# Suppliers and purchasing

Release 1.0 includes organization-wide suppliers and branch-destination purchase
orders with approval, partial/full receiving, immutable receipt history, and
branch-local batch creation with lot, manufacture/expiry, cost, quarantine, and
FEFO integration. The original Phase 16 product-level purchasing workflow was
extended by Phase 17 batch inventory and Phase 24 branch scoping.

Supplier invoices/payments, landed-cost accounting, ERP exchange, and
supplier-return workflows are not implemented. Customer/POS sales returns are a
separate Release 1.0 domain and must not be described as purchasing returns.

## Roles

- **Inventory manager:** manage suppliers; create and edit drafts; add products;
  submit, receive, cancel, close, and view purchasing reports.
- **Administrator:** all inventory-manager abilities plus purchase-order
  approval. This provides one separation point between preparation and approval.
- **Order manager, pharmacist, customer:** no purchasing access.

Authorization is enforced in controllers and transition services. Unauthorized
HTTP access follows the existing not-found behavior. No new role was introduced.

## Supplier lifecycle

Suppliers have a case-insensitive stable code, normalized email and phone,
contact and commercial terms, optional lead time, notes, active state, and
optimistic lock version. Inactive suppliers remain visible in history but cannot
be used for submission or approval. A supplier with purchase orders cannot be
deleted; deactivation is the normal historical-safe operation.

One contact per supplier is sufficient for the current workflow. A separate
supplier-contact model is deferred until multiple named contacts have a concrete
operational use.

## Purchase-order workflow

```text
draft → submitted → approved → partially_received → received → closed
   └───────────────┴───────────────┴──────────────────────→ cancelled
```

- **Draft:** supplier/header and product lines are editable. There is no
  inventory effect.
- **Submitted:** at least one valid item and an active supplier are required.
  Product name/SKU and commercial lines freeze.
- **Approved:** an admin records approval and its timestamp. Receiving becomes
  available, but approval itself has no stock effect.
- **Partially received:** one or more immutable receipts have posted, with an
  outstanding quantity remaining.
- **Received:** every ordered quantity is received; further receipt posting is
  blocked.
- **Closed:** the fully received workflow is finalized and read-only.
- **Cancelled:** no future receipt is allowed. A reason and actor are recorded.
  Previously posted receipts and stock movements remain intact and are not
  automatically reversed.

Explicit services own creation, draft/item editing, submission, approval,
receipt posting, cancellation, and closure. Controllers do not accept arbitrary
status assignment.

## Commercial history and totals

Purchase-order lines store product name and SKU snapshots, ordered and received
quantities, unit cost in integer EGP cents, discount/tax fields, line total, and
notes. Current Phase 16 entry uses quantity and unit cost; discount and tax
fields remain zero until a later explicitly scoped commercial rule needs them.

Line totals and order subtotal/total are recalculated after draft line changes.
Model and database checks protect non-negative money and quantity ranges. Selling
prices and `Product#cost_price` are never updated automatically. Latest and
supplier-specific historical costs are read from immutable receipt/order lines.

## Receiving and inventory invariants

Each receiving submission has a unique idempotency key and creates an immutable
`PurchaseReceipt` plus one `PurchaseReceiptItem` per positive line. The service:

1. checks receiving authorization and an approved/partially-received state;
2. locks the purchase order and lines;
3. validates every quantity against the outstanding amount;
4. locks affected products in deterministic ID order;
5. increases physical product stock;
6. creates one append-only `purchase_received` inventory movement per receipt
   line, referenced to the receipt;
7. updates received quantities and derives partially-received or received state;
8. writes purchase-order timeline and admin-audit events inside the transaction.

A repeated idempotency key returns the original receipt without increasing
stock again. Reservations are not changed or automatically allocated; increased
physical stock only changes the existing availability calculation. Posted
receipts and receipt items cannot be updated or deleted. Corrections require a
future deliberate workflow; controllers cannot edit stock directly.

## Reporting

The purchasing report uses the shared Cairo-aware date-range component and
includes orders and received value, supplier totals, outstanding and overdue
orders, partially received orders, top received products, daily totals, and the
latest received cost per product. CSV exports follow the existing formula-safe,
role-authorized report path.

## Audit and notifications

Supplier create/update/deactivate/activate actions and purchase-order lifecycle
actions write append-only admin audit events. Purchase orders also have an
immutable role-visible timeline. In-app notifications are created for submission,
approval, and receipt posting. These purchasing kinds do not trigger external
email by default.

## Demo scenarios

The deterministic seed includes three fictional suppliers and stable purchase
orders for draft, submitted, overdue-approved, partially received, fully
received, cancelled-without-receipt, and cancelled-after-partial-receipt states.
Two received orders retain different costs for the same product. Guided links
are available only to inventory managers and administrators through normal
authorization.

## Phase 17 boundary

Phase 17 extends each immutable receipt line with one or more batches, mandatory
expiry, batch-linked movements, FEFO reservation allocations, and
expiry/quarantine reporting. See [Batch inventory](batch_inventory.md).

## Branch and tenant destination

Suppliers are organization-wide; each purchase order has one destination branch. Every receipt inherits that destination and creates only branch-local batches/movements. API reads require `purchasing:read`; there is no API stock-mutation endpoint. Purchasing analytics report tenant-scoped spend, volume, supplier/cost trends, overdue orders, partial receipts, and observed—not contractual—lead time.
