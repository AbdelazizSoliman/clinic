# Release 1.0 authorization matrix

This matrix summarizes server-side capability methods and focused controller/
service tests. “Own” means customer-owned records only; “branch” means an
authorized branch membership inside the current organization.

| Domain | Customer | Pharmacist | Order manager | Inventory manager | Admin |
| --- | --- | --- | --- | --- | --- |
| Storefront/cart/checkout | Own | Customer use only | Customer use only | Customer use only | Customer use only |
| Prescription review/safety | Own status; no internal findings | Review, decide, substitute, acknowledge | No clinical action/file access | No clinical action | Rules/report oversight; no pharmacist decision |
| POS | No | Operate/clinical approval | Operate | No cashier operation | Operate/oversight |
| Inventory/batches/transfers | No | Availability only | Operational availability | Branch manage | Branch manage/oversight |
| Purchasing/receiving | No | No | No | Create/submit/receive | Approve/manage |
| Fulfilment/returns | Own requests/history | Clinical inspection where required | Operate | Inventory disposition where authorized | Refund/oversight |
| Loyalty/wallet | Own ledger/history | Identified-customer use via POS | Identified-customer use via POS | No adjustment | Rules/compensating adjustment |
| Reports/analytics | No staff reports | Clinical scopes | Order/POS scopes | Inventory/purchasing scopes | Broad tenant scopes |
| Branch switch | No staff switch | Membership only | Membership only | Membership only | Membership only |
| Tenant management | No | No | No | No | Tenant configuration only; no platform super-admin |
| API/webhook management | No | No | No | No | Scoped integration administration/API boundary |

Representative evidence: `app/models/user.rb`, base controllers under
`app/controllers/{admin,staff,pos}`, `app/controllers/branches_controller.rb`,
`test/controllers/tenant_idor_matrix_test.rb`,
`test/controllers/drug_safety_access_test.rb`,
`test/controllers/api_v1_test.rb`, and service-level tenant/branch tests.
