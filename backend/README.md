# UniFix backend

REST API for the UniFix Flutter app: Node 22 + Express 5 + PostgreSQL 17, run with Docker Compose.
The binding contract is [`../docs/API.md`](../docs/API.md). Base URL: `http://<host>:3000/api/v1`.

## Quick start

```sh
cd backend
cp .env.example .env        # then set POSTGRES_PASSWORD and JWT_SECRET (>= 32 chars)
docker compose up --build
```

The API waits for the database, applies any pending SQL migrations from `migrations/` (tracked in
`schema_migrations`), and listens on port 3000. Check it with `curl http://localhost:3000/api/v1/health`.

Data lives in two named volumes: `db-data` (Postgres) and `uploads` (photos). `docker compose down -v`
deletes both.

### Reaching it from the app

| Where the app runs  | Base URL                         |
|---------------------|----------------------------------|
| Android emulator    | `http://10.0.2.2:3000/api/v1`    |
| iOS simulator / web | `http://localhost:3000/api/v1`   |
| Physical device     | `http://<your-PC-LAN-IP>:3000/api/v1` (allow port 3000 through the firewall) |

Android blocks cleartext HTTP by default, so debug builds need `usesCleartextTraffic` (or a network
security config) for these URLs.

## Making an admin

No endpoint grants admin. Register normally, then:

```sh
docker compose exec api npm run make-admin -- you@adit.ac.in
# or
docker compose exec db psql -U fixmycampus -d fixmycampus -c "UPDATE users SET role='admin' WHERE email='you@adit.ac.in';"
```

The role is re-read from the database on every request, so the change applies immediately; no new login
is needed. To deactivate someone: `UPDATE users SET is_active=false WHERE email='...'`.

## Password reset (v1)

There is no mail server. `POST /auth/password-reset` always returns 204. For an existing, active
account it prints a one-time token (valid 30 min) to the API logs (`docker compose logs api`, look for
`[password-reset]`). Only a SHA-256 hash of the token is stored. The token can be redeemed with
`POST /auth/password-reset/confirm { "token", "newPassword" }` → 204. This endpoint is an addition to
API.md v1.

## v1.1 additions

Implements API.md "v1.1 additions" (all additive; v1 behaviour unchanged). Migration
`002_v1_1.sql` adds `issues.number` (identity, unique; existing rows backfilled 1..n in `created_at`
order without touching `updated_at`), filter/stats indexes and `pg_trgm` indexes for search.

- Issue JSON gains `number`, `code` (`FMC-0483`; 5+ digit numbers print in full) and `assignedToName`;
  IssueUpdate gains `actorName`. Names are read at query time, so renames show up immediately.
- `GET /issues` takes `q` (title / locationDetail / buildingId, case-insensitive substring; `FMC-0483`,
  `0483`, `483` match issue 483 exactly), `open=true`, `priority`, `assigned=true|false`,
  `sort=newest|oldest`. All parameters are bound values; `%`, `_` and `\` in `q` match literally.
- `GET /issues/stats` adds `open urgent unassigned createdLast24h resolvedThisWeek avgResolutionHours
  openByCategory`. `?mine=true` limits to the caller's reports and is the only form students may use.
- `GET /staff` (admin): active admins `[{ id, displayName }]` sorted by name.
- `POST /issues/:id/assign` takes an optional `{ "assigneeId": uuid | null }` (see below).

## v1.3 additions: "Me too" upvotes

Implements API.md "v1.3 additions". Migration `004_upvotes.sql` adds `issue_upvotes (issue_id, user_id)`
(primary key = one vote per user per issue).

- Every Issue now carries `upvoteCount` and `upvotedByMe`, computed in SQL (see `issueColumns()` in
  `src/issues/serialize.js`; it needs the caller's id as a bound parameter).
- `POST /issues/:id/upvote` (idempotent; reporter -> 400, resolved -> 409) and
  `DELETE /issues/:id/upvote` (idempotent, any issue) return the updated Issue.
- `GET /issues?sort=popular`: `upvoteCount` desc, `createdAt` desc, `id` as tiebreak (stable paging).
- `npm run seed-demo` also adds demo upvotes on fresh databases.

## Environment variables

| Variable | Default | Notes |
|---|---|---|
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | `fixmycampus` / required / `fixmycampus` | Used by the `db` container; passed to the API as `PG*` vars |
| `JWT_SECRET` | required | At least 32 characters; the API refuses to start otherwise |
| `PORT` | `3000` | Host and container port |
| `DATABASE_URL` | unset | Alternative to `PGHOST`/`PGUSER`/... (used by tests and local runs) |
| `UPLOADS_DIR` | `./uploads` (`/app/uploads` in Docker) | Photo storage root; temporary uploads go to `<root>/.tmp` |
| `LOG_LEVEL` | `info` (`silent` in tests) | pino level. Authorization headers and bodies are never logged |
| `AUTH_RATE_LIMIT` | `50` | Requests per 15 min per IP on `/auth/*`; `0` disables. Over the limit: `429 RATE_LIMITED` |
| `BCRYPT_ROUNDS` | `12` | bcrypt cost |
| `PG_POOL_MAX` | `10` | Connection pool size |

## Tests

Vitest + supertest. Unit tests (validation, transition table, magic-byte detection, path safety, auth
middleware) need nothing. Integration tests need a real Postgres in `DATABASE_URL`. If `DATABASE_URL`
is unset they are skipped and a warning is printed. The tests TRUNCATE all tables, so they refuse to
run unless the database name contains `test` (override with `ALLOW_DB_RESET=1`).

```sh
npm install
npm run test:unit                      # no database needed
npm run check                          # node --check on every source file

# Integration tests with Docker:
docker compose -f docker-compose.test.yml up --build --abort-on-container-exit --exit-code-from tests
docker compose -f docker-compose.test.yml down

# ...or with the test DB in Docker and tests on the host:
docker compose -f docker-compose.test.yml up -d db-test
DATABASE_URL=postgres://fixmycampus:fixmycampus@localhost:5433/fixmycampus_test npm test
```

## Running without Docker

You need a Postgres 13+ with the `citext` extension available:

```sh
export DATABASE_URL=postgres://user:pass@localhost:5432/fixmycampus JWT_SECRET=...32+chars...
npm install
npm run dev        # node --watch; runs migrations on start
```

## Layout

```
src/
  app.js            Express app factory (exported for tests)
  server.js         startup: wait for DB → migrate → ensure upload dirs → listen
  config.js db.js migrate.js logger.js errors.js domain.js users.js
  middleware/       auth (JWT + DB re-read, requireAdmin), validate (zod helpers), errors (contract error body)
  auth/             /auth/* routes, /me, bcrypt + JWT helpers
  issues/           /issues routes, zod schemas, row → JSON serializers (also stats/staff)
  staff/            GET /staff
  photos/           multer upload, magic-byte check, safe path resolution, GET /photos/*
migrations/         plain SQL, applied in filename order
scripts/            make-admin.js, check-syntax.js
test/unit/          no DB needed
test/integration/   needs DATABASE_URL
```

## Behavior not spelled out in API.md

- `GET /issues/:id/...` with a malformed (non-UUID) id → `404 NOT_FOUND`.
- `POST /issues/:id/feedback` on an issue that is not `resolved` → `409 CONFLICT`. A non-reporter gets
  `403 FORBIDDEN`, on both feedback endpoints.
- `PATCH /issues/:id/status`: the `from → to` pair is checked first (`422`), then staleness (`409`).
  `from == to` is an invalid transition (`422`). The `note` is optional except when the target is
  `resolved`. Reopening keeps the previous `resolutionNote` until the issue is resolved again.
- `PATCH /issues/:id/priority` with `from == to` → `400 VALIDATION`.
- `POST /issues/:id/assign` when the assignee would not change (same admin, or `null` on an unassigned
  issue) → `200`, unchanged, and no history row is added. A non-UUID `assigneeId`, or one that is not an
  active admin of the campus → `400`. The issue is checked first (`404`), then the assignee.
- `GET /issues`: `open=false` and `mine=false` mean "no filter". `q` with more than 9 digits after
  stripping `FMC-`/leading zeros is text-only. A repeated parameter (`?q=a&q=b`) → `400`.
- Issue numbers come from a sequence, so a failed create can leave a gap.
- `POST /issues/:id/resolution-photos` with no files → `400`. Going over 3 in total → `400`. The history
  note is `Added N resolution photo(s).`
- `GET /issues` accepts empty filter values (`?status=&category=`) as "no filter". Out-of-range
  `limit`/`offset` → `400`.
- `GET /photos/...` only serves paths shaped like `issues/<uuid>/(report|resolution)/<uuid>.(jpg|png|webp)`.
  A malformed path → `400`, and a missing file → `404`.
- `/health` returns `503` with code `INTERNAL` when the database is unreachable.
- Rate limiting on `/auth/*` answers `429 RATE_LIMITED`, which is not in the API.md table.
