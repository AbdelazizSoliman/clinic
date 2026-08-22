# Multi-branch operations

Branches are physical operating locations inside one organization. `Current.branch` is resolved from an active `BranchMembership`; submitted branch IDs are checked against that access set. Existing records are backfilled to the deterministic `MAIN` branch.

Inventory batches, reservations, allocations, movements, orders, cashier sessions, POS sales, purchase orders and receipts, returns, and wallet/loyalty entries carry branch provenance. Availability and FEFO allocation are always product + branch. A POS sale uses its cashier session branch, receiving affects only the purchase-order destination branch, and checkout permanently records one deterministic fulfilment branch.

Transfers follow `draft → submitted → dispatched → received → closed`, or cancellation before dispatch. Dispatch locks and decrements source batches and writes `branch_transfer_out`. Receipt recreates branch-local batch rows with source-batch lineage, lot and expiry unchanged, then writes `branch_transfer_in`; no destination stock exists while in transit. Repeated lifecycle commands are idempotent.

Tenant admins may report across their organization. Other operational roles are restricted to the verified current branch. Branch context is visible in staff navigation, POS receipts, inventory, purchasing, returns, transfers, and financial-ledger reports.
