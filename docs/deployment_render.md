# Render deployment plan (Phase 15 executes it)

This phase does not deploy. Create one Docker web service, one Docker worker,
managed PostgreSQL, and private S3-compatible object storage. Build with the
Dockerfile, run `bin/rails db:prepare` as pre-deploy, start web with the image
default command, worker with `bin/jobs start`, and probe `/up`. `/health/ready`
is the database/schema readiness probe.

Before migration: verify a restorable backup, review migration locks/table
sizes, set secrets manually (`sync: false`), precompile assets, and build the
image. Rollback is application-image rollback only when schema remains backward
compatible; otherwise enter maintenance and restore using the approved backup.
Never run destructive down migrations casually.

Initial sizing: three Puma threads, one web process, one worker process with
three threads, and pools no smaller than each process's concurrency. Confirm the
chosen Render PostgreSQL connection ceiling before scaling. Keep web and worker
in the database region; keep storage close to that region.
