# Installation guide

This is the single supported installation path for Saydaliyati. It brings up an
evaluation instance on one machine using Docker Compose, bound to loopback.

The `buyer_evaluation` profile described here is for evaluation and acceptance
testing. It is not a production deployment; see
[Production differences](#production-differences) before serving real users.

## Contents

- [Verification status](#verification-status)
- [1. Prerequisites](#1-prerequisites)
- [2. Configure the environment file](#2-configure-the-environment-file)
- [3. Generate secrets](#3-generate-secrets)
- [4. Run the preflight check](#4-run-the-preflight-check)
- [5. Build and start](#5-build-and-start)
- [6. Verify health](#6-verify-health)
- [7. Create the first administrator](#7-create-the-first-administrator)
- [8. Access the application](#8-access-the-application)
- [9. Evaluation email (Mailpit)](#9-evaluation-email-mailpit)
- [10. Prescription scanning (ClamAV)](#10-prescription-scanning-clamav)
- [11. Evaluation storage](#11-evaluation-storage)
- [Production differences](#production-differences)
- [Common installation failures](#common-installation-failures)
- [Stopping and restarting](#stopping-and-restarting)
- [Removing the installation](#removing-the-installation)

## Verification status

Honest scope of what has been tested, so you know what to expect. This guide was
executed end to end against a live Docker engine (Docker 29.3.1, Compose v5.1.0)
from an empty database and empty Docker volumes.

**Verified by running it:**

- `docker compose config` resolves cleanly; no secret is embedded in
  `compose.yaml`.
- The image builds, runs as non-root (`uid=1000 rails`), uses the production
  bundle, and excludes `debug`, `capybara`, `selenium-webdriver`, and
  `web-console`.
- The startup order holds: `db` healthy → `prepare` exits 0 → `web` and `worker`
  start. Running `prepare` repeatedly does not duplicate data.
- The database reaches 112 tables including all 12 Solid Queue/Cache tables, one
  `DEFAULT` organization, one default `MAIN` branch, and no pending migrations.
- `/up` and `/health/ready` both return 200, and real pages (`/`, `/products`,
  `/users/sign_in`) render.
- The web port publishes on loopback only, never `0.0.0.0`.
- First-admin bootstrap creates the administrator with audit and security events,
  and refuses a second bootstrap.
- Mailpit receives a real application-generated email; its UI is loopback-only.
- ClamAV loads signatures and, through the application's own scanner, returns
  clean for a safe payload, **detects the EICAR test string**, and fails closed
  when unreachable.
- Uploads land on the `app_storage` volume, and the database, administrator, and
  uploaded object all survive `docker compose down` (without `-v`) followed by
  `docker compose up -d`.

**Still a manual check:** completing two-factor enrollment. The enrollment
*boundary* is verified — privileged areas redirect to `/two_factor_enrollment`,
the QR renders, an invalid code is rejected, and logout invalidates the session.
Finishing enrollment needs a real authenticator app scanning the QR, because the
secret is deliberately never rendered as text. Do this once yourself at step 8.

## 1. Prerequisites

- Docker Engine 24+ with the Compose v2 plugin (`docker compose version`).
- 4 GB RAM available to Docker. ClamAV alone needs roughly 1.5 GB to load its
  signature database.
- Free loopback ports `3000` (application) and `8025` (Mailpit web UI).
- No host PostgreSQL, Ruby, or Node installation is required. Everything runs
  inside containers.

Confirm the engine is reachable before continuing:

```bash
docker --version
docker compose version
```

## 2. Configure the environment file

```bash
cp .env.example .env
```

Open `.env` and replace every `change-me` value. The file is already set to the
supported evaluation defaults:

| Variable | Value | Why |
| --- | --- | --- |
| `RAILS_ENV` | `production` | The only environment the Compose path supports. |
| `INSTALLATION_PROFILE` | `buyer_evaluation` | Unlocks loopback HTTP, local storage, and unauthenticated SMTP. |
| `APP_HOST` | `localhost` | Must stay loopback under this profile. |
| `WEB_BIND_ADDRESS` | `127.0.0.1` | Keeps the published port off your network. Required; do not delete this line. |
| `FORCE_SSL` | `false` | Permitted only for loopback evaluation. |

`.env` is ignored by git. Never commit it.

`DATABASE_URL` is deliberately absent — `compose.yaml` builds it from the
`POSTGRES_*` values.

## 3. Generate secrets

Order matters. `compose.yaml` refuses to interpolate without the `POSTGRES_*`
values, so set those first, then build the image, then generate the rest inside
it.

```bash
# 1. Database password — set this in .env before any other compose command.
openssl rand -hex 32

# 2. Build the image so the remaining generators can run inside it.
docker compose build web

# 3. SECRET_KEY_BASE and SECURITY_EVENT_DIGEST_KEY (run once per value).
docker compose run --rm --no-deps web ./bin/rails secret

# 4. The three ACTIVE_RECORD_ENCRYPTION_* values.
docker compose run --rm --no-deps web ./bin/rails db:encryption:init
```

Step 4 prints YAML. Map its keys onto the environment variables by hand:

| Printed key | `.env` variable |
| --- | --- |
| `primary_key` | `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` |
| `deterministic_key` | `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` |
| `key_derivation_salt` | `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` |

Keep these three values safe. Losing them makes existing encrypted data
unreadable.

Set `ADMIN_PASSWORD` to at least 12 random characters from a password manager.
The bootstrap refuses common placeholder passwords.

`--no-deps` keeps these commands from starting the database.

## 4. Run the preflight check

Validate the finished `.env` **before** anything creates a database:

```bash
docker compose run --rm --no-deps web ./bin/rails installation:preflight
```

It exits `0` and prints `PASS` for each of nine checks, ending with:

```
PASS installation preflight: environment is ready for the supported boot path.
```

Any misconfiguration exits non-zero and names the variable to correct. Fix `.env`
and re-run until it passes. Do not continue past a failure.

`--no-deps` matters here: without it, Compose starts the database and runs the
`prepare` service first, so the database would be created before the
configuration was ever validated.

## 5. Build and start

```bash
docker compose up -d --build
```

Compose enforces this order:

1. `db` starts and must report healthy (`pg_isready`).
2. `prepare` runs `./bin/rails db:prepare` once and must exit successfully. This
   creates the schema, the DEFAULT organization and MAIN branch, the starter
   catalog, and the Solid Queue and Solid Cache tables.
3. `web` and `worker` start only after `prepare` has completed successfully.

Only `prepare` touches the database schema. `web` sets `SKIP_DB_PREPARE=true`,
and `worker` does not run the server command, so neither repeats the preparation
step and the services cannot race.

First start is slow: the image build plus the ClamAV signature download typically
takes several minutes.

## 6. Verify health

```bash
docker compose ps
```

Expect `db`, `web`, `worker`, `mailpit`, and `clamav` running, and `prepare`
exited with code `0`. `db`, `web`, `mailpit`, and `clamav` report `(healthy)`.
`worker` shows plain `Up` — it runs no HTTP server, so it carries no healthcheck.

Confirm the worker is actually processing by checking that it has registered and
is still beating:

```bash
docker compose exec db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -c "select kind, last_heartbeat_at from solid_queue_processes order by kind;"
```

Expect four rows — `Dispatcher`, `Scheduler`, `Supervisor(fork)`, and `Worker` —
with heartbeats a few seconds old. No rows, or heartbeats minutes old, means the
worker is not running; check `docker compose logs worker`.

```bash
curl -i http://127.0.0.1:3000/up
curl -i http://127.0.0.1:3000/health/ready
```

- `/up` returns `200` when the application boots without raising. It does **not**
  check the database — a `200` here alone does not mean the install is good.
- `/health/ready` returns `200` with `{"status":"ready"}` only when the database
  is reachable and no migrations are pending. It returns `503` with
  `{"status":"unavailable"}` otherwise. **This is the endpoint that matters.**

Confirm the port is loopback-only and not exposed to your network:

```bash
docker compose port web 3000    # expect 127.0.0.1:3000
```

## 7. Create the first administrator

```bash
docker compose run --rm web ./bin/rails users:create_admin
```

This reads the `ADMIN_*` values from `.env` and creates one administrator in the
`DEFAULT` organization with `MAIN` as the default branch, writing an audit event
and a security event. It prints a confirmation and never echoes the password.

It deliberately refuses to run a second time for the same organization. That is
the intended guard, not a failure. Create any further administrators from inside
the application once you are signed in.

## 8. Access the application

Open <http://localhost:3000> and sign in with `ADMIN_EMAIL` and `ADMIN_PASSWORD`.

Administrative and staff areas require two-factor authentication. The first time
you open one you are redirected to `/two_factor_enrollment`, which asks for your
password again and then shows a QR code. Scan it with an authenticator app and
enter the six-digit code. You are then issued single-use recovery codes — store
them somewhere safe, as they are shown once.

Until you complete enrollment, every privileged area keeps redirecting to the
enrollment page. This is by design and cannot be skipped.

## 9. Evaluation email (Mailpit)

All outbound mail is captured by the bundled Mailpit container. Nothing is sent
to a real recipient. Read captured messages at <http://127.0.0.1:8025>.

Mailpit is unauthenticated and stores messages in memory. It is for evaluation
only — replace it with authenticated SMTP before production.

## 10. Prescription scanning (ClamAV)

Prescription uploads are scanned by the bundled ClamAV container before a
pharmacist can act on them. This is a required part of the installation, not an
optional extra.

The scanner **fails closed**: if ClamAV is unreachable, misconfigured, or times
out, the upload is marked `failed` and the job retries. It is never silently
treated as clean.

ClamAV needs a minute or two after first start to download its signature
database. Uploads attempted during that window fail closed and retry — wait for
the container to settle rather than disabling the scanner.

Never set `MALWARE_SCANNER_ADAPTER` to anything but `clamav` in an installation
that handles real uploads. Preflight rejects any other value.

## 11. Evaluation storage

Uploads are written to the `app_storage` Docker volume, mounted at
`/rails/storage` inside the containers. The volume persists across
`docker compose restart` and `docker compose down`.

This local disk service is evaluation-only. It has no redundancy, no offsite
copy, and no lifecycle policy, and it is available only because
`INSTALLATION_PROFILE=buyer_evaluation`. Preflight rejects `STORAGE_SERVICE=local`
under any other profile.

## Production differences

The evaluation profile is deliberately permissive. A production deployment must
change all of the following:

| Area | Evaluation | Production requirement |
| --- | --- | --- |
| Transport | Plain HTTP on loopback | TLS termination at a reverse proxy; `FORCE_SSL=true`, `APP_PROTOCOL=https` |
| Cookies | Not secure-only | Secure cookies and HSTS, enabled by `FORCE_SSL=true` |
| Storage | Local Docker volume | Private S3-compatible bucket: set `STORAGE_SERVICE=production` plus `STORAGE_ACCESS_KEY_ID`, `STORAGE_SECRET_ACCESS_KEY`, `STORAGE_REGION`, `STORAGE_BUCKET`. The bucket must not be public. |
| Mail | Unauthenticated Mailpit | Authenticated SMTP: set `SMTP_AUTHENTICATION` to `plain`/`login`/`cram_md5` plus `SMTP_USERNAME` and `SMTP_PASSWORD` |
| Profile | `buyer_evaluation` | `INSTALLATION_PROFILE=production`, which makes preflight reject local storage and unauthenticated mail |
| Binding | `127.0.0.1` | Behind a reverse proxy; set `APP_HOST` and `ALLOWED_HOSTS` to the real hostname |
| Backups | None | Scheduled `pg_dump` plus object-storage backups, with restore rehearsals |
| Monitoring | Container healthcheck only | External uptime checks on `/health/ready`, log shipping, and error reporting |

Also review the starter catalog. `db/seeds.rb` installs a fictional Arabic
demonstration catalog (categories, brands, products, delivery zones). Replace it
with real data before serving customers.

## Common installation failures

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Set POSTGRES_USER` / `Set POSTGRES_PASSWORD` when any compose command runs | `.env` missing or `POSTGRES_*` still placeholders | Complete step 2 and the first command in step 3. |
| `ports are not available: exposing port TCP 127.0.0.1:3000` — `db`, `prepare` and `worker` come up but `web` stays `Created` | Something else on the host already listens on port 3000, a very common development port | Set `WEB_PORT` in `.env` to a free port (e.g. `3100`) and re-run `docker compose up -d`. Keep `WEB_BIND_ADDRESS=127.0.0.1`. Find the holder with `ss -tlnp \| grep :3000`. |
| `error getting credentials` / `docker-credential-*` failures on any pull | Host Docker credential helper is broken; unrelated to this application | Repair your Docker installation's credential helper. All images used here are public and need no login. |
| Preflight: `replace unsafe or short values` | A secret is still a placeholder or under 24 characters | Regenerate it with the step 3 commands. |
| Preflight: `buyer evaluation requires a loopback WEB_BIND_ADDRESS` | `WEB_BIND_ADDRESS` was deleted or set to a routable address | Restore `WEB_BIND_ADDRESS=127.0.0.1`. It is required even though Compose would otherwise default it. |
| Preflight: `set: DATABASE_URL` | Preflight was run outside Compose | Run it through `docker compose run`, which injects `DATABASE_URL`. |
| `prepare` exits non-zero and `web`/`worker` never start | Preparation failed; the dependency gate is working as intended | `docker compose logs prepare`, fix the cause, then `docker compose up -d` again. |
| `PG::UndefinedTable: relation "solid_cache_entries" does not exist` on every page while `/up` still returns 200 | The Solid Queue/Cache tables were not created | `docker compose run --rm web ./bin/rails installation:solid_schemas`, then restart `web` and `worker`. |
| `Admin bootstrap refused: ADMIN_ORGANIZATION_CODE does not identify an active organization` | The `prepare` step did not complete, so no DEFAULT organization exists | Check `docker compose logs prepare`; re-run `db:prepare` before bootstrapping. |
| `Admin bootstrap refused: an administrator already exists` | An administrator was already created | Expected. Sign in and add further users from the application. |
| `Admin bootstrap refused: ADMIN_PASSWORD is an unsafe example value` | Placeholder password | Set a real 12+ character password. |
| Prescription scans stuck as `failed` | ClamAV still loading signatures, or unreachable | `docker compose logs clamav`; wait for it to settle. Do not disable the scanner. |
| `/health/ready` returns 503 | Database unreachable or migrations pending | `docker compose logs db`; confirm `prepare` exited 0. |

## Stopping and restarting

```bash
docker compose stop            # stop, keep all data
docker compose start           # start again
docker compose restart web     # restart one service
docker compose down            # remove containers, KEEP volumes and data
docker compose up -d           # bring everything back
```

Data in `postgres_data`, `app_storage`, and `clamav_data` survives all of the
above. After a restart, `/health/ready` should return `200` again and the worker
should re-register.

## Removing the installation

> **Back up first.** `docker compose down -v` **permanently deletes** the
> `postgres_data`, `app_storage`, and `clamav_data` volumes. That destroys the
> database, every uploaded prescription and document, and all accounts including
> the bootstrap administrator. There is no undo and no prompt.

Take a backup before you consider it.

Compose prefixes volume names with the project name, which defaults to the name
of the directory you cloned into. Ask Compose for the real name rather than
guessing it:

```bash
# Resolve this project's real storage volume name (do not hardcode it).
STORAGE_VOLUME=$(docker compose config --format json \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["volumes"]["app_storage"]["name"])')
echo "$STORAGE_VOLUME"        # prints this project's real volume name

# Database dump.
docker compose exec db pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > backup.sql

# Uploaded documents.
docker run --rm -v "$STORAGE_VOLUME":/data -v "$PWD":/out alpine \
  tar czf /out/storage-backup.tar.gz -C /data .
```

If you would rather not use `python3`, list the volumes and pick the one ending
in `_app_storage`:

```bash
docker volume ls --filter label=com.docker.compose.volume=app_storage
```

Only then:

```bash
docker compose down -v
```

See [backup_restore.md](backup_restore.md) for the fuller procedure.
