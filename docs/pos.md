# Pharmacy POS — Phase 18

Phase 18 adds an Arabic RTL counter-sale workflow for one pharmacy. It is an
in-application cash register, not a payment gateway or hardware integration.

## Architecture decision

POS uses a dedicated `PosSale` aggregate rather than overloading `Order`.
Online orders require a customer, cart, address, delivery zone, fulfilment and a
multi-step delivery state machine. A counter sale is immediate, may be
anonymous, has no delivery record, and belongs to a cashier session. Keeping
these lifecycles separate avoids invented delivery data. Both workflows share
product pricing, `InventoryBatch`, FEFO, append-only movements, audit and
reporting infrastructure.

A draft `PosSale` is the temporary cart. It has no inventory effect and creates
no reservation, so abandoned drafts cannot strand stock. Duplicate products
merge into one line.

## Roles

- Admin: operate POS, oversee sessions, approve manual discounts, reports.
- Pharmacist: operate POS and approve prescription-required POS lines.
- Order manager: operate POS and view POS reports.
- Inventory manager: POS reports only.
- Customer: no POS access.

Server-side capability checks use the existing not-found denial. An admin cannot
approve a prescription line merely because they are an admin; the approving
actor must be a pharmacist.

## Sessions and cart

A cashier opens a session with a non-negative opening balance. A partial unique
index enforces one open session per user. Completion and close both lock the
session, preventing close from racing a sale.

Closing is blocked while drafts remain. Expected cash is opening cash plus
completed cash payment amounts; refunds are zero in Phase 18. Counted cash and
the derived difference are stored. A difference of EGP 5 or more needs a note.
Closed sessions are immutable.

The POS page supports exact single-barcode lookup, SKU lookup and
case-insensitive name/description search. Keyboard-wedge scanners use the
focused barcode field and Enter; there is no global key capture. Search is
debounced by Stimulus and the server remains authoritative.

## Pricing, prescription and payment

Product identity and commercial values are snapshotted. Existing automatic
promotions are recalculated server-side. Coupons remain online-checkout
features. A manual fixed discount requires an admin, reason, actor and timestamp
and cannot make a sale negative.

Each prescription-required line needs its own pharmacist approval before
completion. The approval records actor, timestamp and a concise reason. It
cannot be reused by another line. Receipts show only that approval occurred.

Supported payments are cash and a manual external-card-terminal marker. The app
stores no card number, CVV or verification claim. Applied amounts must equal the
sale total. Cash may have a larger tendered amount; change is derived.

## Completion, FEFO and idempotency

`Pos::Complete` runs one database transaction:

1. resolve an existing sale by completion idempotency key;
2. lock the cashier session and draft;
3. recalculate pricing and validate lines and approvals;
4. validate payment equality;
5. lock products and eligible batches in stable FEFO order;
6. consume earliest expiry, oldest receipt, then stable batch ID;
7. append a `pos_sale` movement and persisted allocation per batch;
8. synchronize the product compatibility aggregate;
9. persist payments, snapshots, audit and completion state.

Expired, quarantined and zero-available batches are excluded. One line can
consume several batches. The unique completion key and movement idempotency keys
make a retry return the completed sale without another payment, receipt,
allocation, audit event or stock change. Failure rolls the whole transaction
back.

Only drafts can be voided, and drafts never affect stock. Completed sales are
immutable and cannot be reversed in Phase 18.

## Receipts, reconciliation and reports

The Arabic RTL browser-print receipt includes pharmacy identity, receipt,
cashier, time, item snapshots, discounts, total, payment, tender and change. It
contains no prescription reason or sensitive payment data.

Traceability is `session → sale → item → batch allocation → batch → movement`.
POS reports use Cairo-aware ranges and cover totals, cashiers, sessions, payment
methods, products, discounts, prescription items, reconciliation and batch
allocations. CSV uses the existing UTF-8 BOM, row cap and formula neutralization.

Stable row locking serializes two cashiers competing for final units. The second
completion recalculates availability and fails without partial effects. Session
close also serializes with completion.

Phase 19 owns prescription substitution. Phase 22 owns returns, refunds and
completed-sale reversal. Real gateways, stored cards, offline mode, printer and
drawer hardware, loyalty, customer credit, multi-branch scope and ERP
integration remain out of scope.
