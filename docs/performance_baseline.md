# Local performance and query baseline

Measured 2026-07-16 with Ruby 3.4.6, Rails 8.1.3, PostgreSQL, 24 seeded
products, development mode, one warm local process. These figures are
repeatable diagnostics—not production capacity or load-test results.

| Request | SQL queries | Local duration | HTML bytes |
|---|---:|---:|---:|
| `/` | 20 | 594 ms | 65,689 |
| `/products` | 8 | 211 ms | 61,947 |
| `/products/panadol-advance-24` | 11 | 112 ms | 44,350 |

Preloading product images/blobs and active reservations reduced the same local
measurements from 111/79/31 queries respectively. Listing pages are capped at
12 products; reports and operational lists use pagination or explicit limits.
Staff orders, prescriptions, admin products, reports, and the security dashboard
must be remeasured with production-shaped data in Phase 15 because tiny fixtures
cannot reveal realistic joins, cache behavior, or cardinality.

Representative `EXPLAIN (ANALYZE, BUFFERS)` for the storefront product ordering
used a sequential scan and in-memory quicksort over 24 rows, 0.146 ms execution,
37 kB sort memory, and 14 shared-buffer hits. No index was added: this plan is
correct for the tiny table. Re-run after realistic data import; consider a
partial composite index only if the planner and measured latency justify it.

Risks: report row materialization remains bounded at 10,000 but uses memory;
asynchronous export moves latency off the request without removing that bound.
Image variants have fixed dimensions and are cached by Active Storage. Monitor
variant queue latency, object-store latency, database pool waits, slow report
queries, response size, and N+1 regressions at launch.
