# Job and scheduler architecture

Production uses Solid Queue in PostgreSQL and a separate `bin/jobs start`
worker. Finished queue records are cleaned hourly. Reservation expiration runs
every five minutes and invitation expiry hourly. The recurring registry is
`config/recurring.yml`; execution, not enqueueing, updates `JobHeartbeat`.

Jobs must be idempotent, use `Time.current`, pass record identifiers rather than
files/tokens, and never log arguments. A worker restart does not lose queued
jobs. Operators should alert when reservation expiry has no successful heartbeat
for 15 minutes or invitation expiry for three hours.

Report generation runs on `exports`, tracked notification mail on `mailers`, and
expired report cleanup daily at 02:30. Export and delivery jobs are idempotent:
completed/cancelled records are not sent again and active identical exports are
deduplicated.
