# API v1

Base path: `/api/v1`. Send `Authorization: Bearer <token>`. `ApiClients::Credentials.issue!` returns plaintext once; only a SHA-256 digest and non-secret prefix are stored. Rotation replaces the credential, revocation is immediate, optional expiry is supported, and create/rotate/revoke/scope changes are audited without secrets.

Scopes are `catalog:read`, `inventory:read`, `orders:read`, `orders:write`, `purchasing:read`, `reports:read`, and `webhooks:manage`. A token resolves exactly one organization; submitted tenant IDs are ignored and guessed cross-tenant record IDs return the standard not-found response.

Read endpoints:

- `GET /api/v1/products[/:id]`, `/branches`, `/inventory`, `/orders[/:id]`;
- `GET /api/v1/purchase_orders[/:id]` with `purchasing:read`;
- `GET /api/v1/returns[/:id]` with `orders:read`.

Collections use bounded `page`/`per_page` pagination. Errors use `{ "error": { "code", "message", "fields", "request_id" } }` and never expose stack traces.

Order cancellation and webhook mutations require `Idempotency-Key`. Identity is organization + client + action + key. Exact replay returns the stored result; a changed payload returns 409; the same key remains independent for another credential. Credential-based rate limiting returns 429 before write execution.

Webhook management supports list, show, create, subscription update, deactivation, and secret rotation under `webhooks:manage`. A generated secret appears only in the first response and is not retained in idempotency metadata. Events include order changes/completion, inventory changes, completed returns, and received purchase orders.

Signatures use `hex(HMAC-SHA256(secret, "timestamp.delivery_id.body"))` with timestamp and delivery-ID headers. Deliveries are persisted, asynchronous, retried to a terminal state, and retain only bounded response metadata. Targets require HTTPS, no URL credentials, and DNS/IP validation rejecting localhost, loopback, link-local, private IPv4, and private IPv6. Redirects are not followed. Tests stub all network access; demo data contains no real credential or target.
