# Batch inventory, expiry, and FEFO

Phase 18 POS uses the same batch aggregate. Draft carts do not reserve;
completion locks eligible batches in FEFO order, persists
`PosSaleBatchAllocation`, appends `pos_sale` movements and synchronizes the
product compatibility aggregate. See [pos.md](pos.md).

Phase 17 makes `InventoryBatch` the pharmaceutical stock aggregate root.
`Product#stock_quantity` remains a compatibility aggregate cache and must equal
the sum of batch on-hand quantities.

## Lifecycle

Each batch has immutable product and receipt provenance, a globally unique
normalized batch number, optional lot/manufacture date, mandatory expiry,
received cost, original quantity, physical on-hand quantity, reserved quantity,
and optimistic lock. Its displayed state is derived as available, reserved,
partially consumed, consumed, expired, or quarantined.

Quantity changes use append-only batch-linked inventory movements. Quality holds
use append-only batch events and admin audit events.

## Receiving, FEFO, and fulfilment

Phase 16 receipt idempotency and approval remain intact. Each receipt line is
split into one or more batches, with a movement recording both product and batch
before/after quantities.

The existing reservation is the commercial parent.
`InventoryReservationAllocation` splits it across locked eligible batches by
earliest expiry, oldest receipt timestamp, then stable batch ID. Expired,
quarantined, and empty batches are excluded. Cancellation releases allocations.
Transition to ready-for-delivery consumes them, updates the batch aggregate, and
appends one idempotent movement per allocation.

This traces customer → order → reservation allocation → batch → receipt →
supplier → purchase order, and supports reverse navigation.

## Expiry, reports, and limitations

`near_expiry_threshold_days` defaults to 90. Expired stock remains physical but
is excluded from sale and FEFO; near-expiry stock remains allocatable. Quality
hold is blocked while a batch has active reservations.

Arabic pages and CSV cover batch inventory, expiry, quarantine, supplier and
receipt provenance, movements, FEFO exceptions, and received-cost valuation.
Phase 17 excludes POS, returns, substitutions, multi-branch inventory, RFID or
barcode printing, warehouse optimization, ERP, analytics, and AI.

Returned stock always traces to its original allocation. Sellable restocks increase the same safe batch; quarantined custody increases `returned_quarantine_quantity`, which is excluded from FEFO availability; write-off/destroy decisions remain append-only movements.
