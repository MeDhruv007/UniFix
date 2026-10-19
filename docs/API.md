# FixMyCampus REST API (v1)

Contract between the Flutter app (Dio) and the backend (`backend/`, Node + Express + PostgreSQL, run with Docker Compose). Both sides must follow this file exactly; change it first if the contract changes.

## Conventions

- Base URL: `http://<host>:3000/api/v1`. From the Android emulator the host is `10.0.2.2`.
- JSON bodies, `camelCase` keys, timestamps as ISO-8601 UTC strings (`2026-10-15T14:03:00.000Z`), nullable fields sent as `null` (never omitted).
- Auth: `Authorization: Bearer <JWT>` on every endpoint except `/auth/register`, `/auth/login`, `/auth/password-reset`, `/health`. JWT payload `{ sub: userId, role }`, expiry 7 days. The server re-reads the user row on every request; `role` and `isActive` from the DB are authoritative.
- IDs are UUID strings.
- Campus is fixed to `adit-main` in v1 (server sets it; clients never send it).
- Enums (stored and sent as these exact strings):
  - status: `reported` `inProgress` `resolved` `reopened`
  - priority: `low` `medium` `high` `urgent`
  - category: `electrical` `plumbing` `cleanliness` `furniture` `it` `safety` `other`
  - update action: `created` `statusChanged` `priorityChanged` `assigned` `commented` `reopened`
  - role: `student` `admin`
- Allowed status transitions: `reported→inProgress`, `inProgress→resolved`, `resolved→reopened`, `reopened→inProgress`, `reopened→resolved`.

### Errors

Every non-2xx response has the body:
```json
{ "error": { "code": "VALIDATION", "message": "Title must be at least 5 characters." } }
```
| HTTP | code | When |
|---|---|---|
| 400 | `VALIDATION` | Bad/missing field, bad enum, length limits, too many photos, bad image type |
| 401 | `UNAUTHENTICATED` | Missing/invalid/expired token, wrong email or password (`message` must not reveal which) |
| 403 | `FORBIDDEN` | Not admin, not the reporter, account deactivated (`code` `ACCOUNT_DISABLED`) |
| 404 | `NOT_FOUND` | Unknown issue/route |
| 409 | `CONFLICT` | Email already registered; stale `from` status/priority; feedback already given |
| 413 | `PAYLOAD_TOO_LARGE` | Photo over 5 MB |
| 422 | `INVALID_TRANSITION` | Status transition not allowed |
| 500 | `INTERNAL` | Anything else (no stack traces in the body) |

`message` is always safe to show to end users.

## Objects

**User**
```json
{ "id": "uuid", "displayName": "Asha Patel", "email": "asha@adit.ac.in",
  "role": "student", "campusId": "adit-main", "department": "Computer", "isActive": true,
  "createdAt": "…", "updatedAt": "…" }
```

**Issue**
```json
{ "id": "uuid", "campusId": "adit-main", "title": "Fan not working in Room 204",
  "description": "The ceiling fan does not start.", "category": "electrical",
  "buildingId": "engineering-block", "locationDetail": "Second floor, Room 204",
  "photoPaths": ["issues/<issueId>/report/<uuid>.jpg"],
  "reporterId": "uuid", "reporterDisplayName": "Asha Patel",
  "status": "reported", "priority": "medium", "assignedTo": null,
  "resolutionNote": null, "resolutionPhotoPaths": [],
  "createdAt": "…", "updatedAt": "…", "resolvedAt": null, "reopenCount": 0 }
```

**IssueUpdate**
```json
{ "id": "uuid", "actorId": "uuid", "action": "statusChanged",
  "oldStatus": "reported", "newStatus": "inProgress",
  "oldPriority": null, "newPriority": null, "note": "Electrician assigned", "createdAt": "…" }
```

**Feedback**
```json
{ "issueId": "uuid", "reporterId": "uuid", "stillExists": false, "comment": null, "createdAt": "…" }
```

## Limits (validate server-side; the app mirrors them)
title 5–100 · description 10–1000 · locationDetail 2–120 · note/comment ≤ 500 · displayName 2–60 · department ≤ 60 · password ≥ 8 · email valid format · photos ≤ 3 per issue (report) and ≤ 3 resolution photos · each photo ≤ 5 MB, `image/jpeg|png|webp` checked by file signature (magic bytes), not just extension. All strings trimmed before validation. `buildingId` must be one of: `engineering-block science-block admin-block library workshop canteen hostel sports-complex auditorium grounds`.

## Endpoints

### Health
`GET /health` → `200 { "status": "ok" }` (also checks DB connectivity).

### Auth
| Method & path | Body | Response |
|---|---|---|
| `POST /auth/register` | `{ displayName, email, password, department? }` | `201 { token, user }` — role is always `student` (any `role` in the body is ignored) |
| `POST /auth/login` | `{ email, password }` | `200 { token, user }`; deactivated → 403 `ACCOUNT_DISABLED` |
| `POST /auth/password-reset` | `{ email }` | `204` always (no account enumeration). v1 has no mail server: the server logs a reset token to stdout. |
| `GET /me` | — | `200 User` |
| `PATCH /me` | `{ displayName?, department? }` (only these; omitted = unchanged, `department: ""` clears it to `null`) | `200 User` |

### Issues
| Method & path | Who | Notes |
|---|---|---|
| `GET /issues?status=&category=&mine=true&limit=20&offset=0` | any user | Newest first. `mine=true` → only the caller's reports. `limit` 1–50 (default 20). Response `200 { "items": [Issue], "total": 57 }` |
| `POST /issues` | any user | `multipart/form-data`: text fields `title, description, category, buildingId, locationDetail` + 0–3 files in field `photos`. Server creates the issue (status `reported`, priority `medium`) **and** a `created` history entry in one DB transaction; if anything fails, saved files are deleted. `201 Issue` |
| `GET /issues/:id` | any user | `200 Issue` |
| `GET /issues/:id/updates` | any user | Oldest first. `200 [IssueUpdate]` |
| `PATCH /issues/:id/status` | admin | `{ from, to, note? }`. 409 if current status ≠ `from`; 422 if transition invalid. To `resolved`: sets `resolvedAt`, and `resolutionNote` = note (required, non-empty, for resolve). To `reopened`: clears `resolvedAt`, `reopenCount += 1`, history action `reopened`; otherwise action `statusChanged`. Issue update + history row in one transaction. `200 Issue` |
| `PATCH /issues/:id/priority` | admin | `{ from, to }`; 409 if stale. History `priorityChanged`. `200 Issue` |
| `POST /issues/:id/assign` | admin | Assigns to the caller. History `assigned`, note `Assigned to <name>`. `200 Issue` |
| `POST /issues/:id/resolution-photos` | admin | multipart field `photos` (1–3, total ≤ 3). History `commented`. `200 Issue` |
| `GET /issues/stats` | admin | `200 { "reported": 4, "inProgress": 2, "resolved": 9, "reopened": 1, "total": 16 }` |
| `GET /issues/:id/feedback/me` | reporter | `200 Feedback` or `404` if none |
| `POST /issues/:id/feedback` | reporter of that issue, issue status `resolved` | `{ stillExists, comment? }`; one per reporter per issue (409 on repeat). `201 Feedback` |

Issues are never deleted through the API.

### Photos
`GET /photos/<photoPath>` (e.g. `/photos/issues/<id>/report/<uuid>.jpg`) — any authenticated user; streams the file with the correct `Content-Type`; rejects path traversal. The app loads images with the `Authorization` header.

## Clarifications (as implemented in `backend/`)
- `POST /auth/password-reset/confirm { token, newPassword }` → `204`, or `400` if the token is invalid/expired. Tokens are single-use, expire after 30 min, stored hashed. (No app screen for this yet.)
- `429 RATE_LIMITED` on `/auth/*` when rate-limited; `/health` returns `503` when the DB is down.
- Status change: the `from→to` pair is validated first (`422`, including `from == to`), then staleness (`409`). Reopening keeps the previous `resolutionNote`.
- Priority with `from == to` → `400`. Assigning an issue already assigned to the caller → `200`, unchanged, no history row.
- Resolution photos: 0 files or a total over 3 → `400`.
- Feedback on an issue that is not `resolved` → `409`; a non-reporter gets `403` on both feedback endpoints.
- Malformed (non-UUID) ids → `404`. Empty query filters mean "no filter"; out-of-range `limit`/`offset` → `400`. Passwords are capped at 72 bytes.
- Only `issues/<uuid>/(report|resolution)/<uuid>.(jpg|png|webp)` is served under `/photos`; malformed → `400`, missing → `404`.
- Login on a deactivated account returns `ACCOUNT_DISABLED` only after a correct password.

## v1.1 additions (for the "Screens v2" design)

All additive; existing fields and endpoints are unchanged.

### Object changes
- **Issue** gains:
  - `number` (integer, sequential per database, starts at 1) and `code` (string, `"FMC-" + number zero-padded to 4`, e.g. `"FMC-0483"`).
  - `assignedToName` (string|null) — display name of `assignedTo`.
- **IssueUpdate** gains `actorName` (string) — display name of `actorId` at read time.

### `GET /issues` new query params
| Param | Meaning |
|---|---|
| `q` | Case-insensitive search over title, locationDetail, buildingId and code (`FMC-0483`, `0483` and `483` all match issue 483). Trimmed; 1–100 chars; empty = no search. |
| `open=true` | Only `reported`, `inProgress`, `reopened`. Combinable with `status` (then both must hold). |
| `priority` | One of the priority enums. |
| `assigned` | `true` = has an assignee, `false` = unassigned. |
| `sort` | `newest` (default, `createdAt desc`) or `oldest` (`createdAt asc`). |

### `GET /issues/stats` (extended)
- Admin: whole campus. Any user with `mine=true`: only the caller's reports (admins too). Without `mine=true` a student gets `403`.
- Response keeps `reported inProgress resolved reopened total` and adds:
```json
{ "open": 34, "urgent": 7, "unassigned": 19,
  "createdLast24h": 12, "resolvedThisWeek": 34,
  "avgResolutionHours": 57.6,
  "openByCategory": { "electrical": 38, "plumbing": 27, "cleanliness": 22, "furniture": 13, "it": 18, "safety": 7, "other": 0 } }
```
- `open` = reported+inProgress+reopened. `urgent`/`unassigned` count **open** issues only. `resolvedThisWeek` = resolved within the last 7 days (by `resolvedAt`). `avgResolutionHours` = mean of `resolvedAt − createdAt` over currently resolved issues, `null` if none, rounded to 1 decimal. `openByCategory` always contains all 7 categories.

### Staff
- `GET /staff` (admin) → `200 [{ "id": "uuid", "displayName": "S. Patel" }]` — active admins of the campus, sorted by name.
- `POST /issues/:id/assign` body is now optional `{ "assigneeId": "uuid" | null }`:
  - no body / `{}` → assign to caller (unchanged behaviour);
  - `assigneeId` of an active admin → assign to them (`400 VALIDATION` if not an active admin);
  - `null` → unassign.
  - History `assigned` entry note: `Assigned to <name>` or `Unassigned`. No row if nothing changes.

## v1.2 additions
- **User** gains `avatar` (string|null): a preset id, one of `spark leaf wave sun star bolt heart book`.
- `PATCH /me` also accepts `avatar` (one of the ids, or `null` to clear). Unknown ids → `400 VALIDATION`.
- Demo data: `docker compose exec api npm run seed-demo` adds 3 staff, 6 students and 30 issues (password `password123` for all). Runs once; re-running does nothing.

## v1.3 additions: "Me too" (upvotes)
- **Issue** gains `upvoteCount` (int: how many people said "me too"; the reporter is not counted) and `upvotedByMe` (bool, for the caller).
- `POST /issues/:id/upvote` → `200 Issue`. Idempotent: already upvoted is still `200`. Errors: the reporter of the issue → `400 VALIDATION` ("You reported this issue."); issue is `resolved` → `409 CONFLICT`; unknown id → `404`.
- `DELETE /issues/:id/upvote` → `200 Issue`. Idempotent: not upvoted is still `200`. Allowed on any issue.
- `GET /issues` accepts `sort=popular` (`upvoteCount` desc, then `createdAt` desc). `newest` (default) and `oldest` are unchanged.
- One upvote per user per issue. Any signed-in active user except the reporter may upvote (admins included).

## Admin provisioning
No endpoint grants admin. Promote a user from the host:
```
docker compose exec db psql -U fixmycampus -d fixmycampus -c "UPDATE users SET role='admin' WHERE email='you@adit.ac.in';"
```
(or `npm run make-admin -- you@adit.ac.in` inside the api container).

## v1.4 — "My tasks"

- `GET /issues?assignedToMe=true` — only issues assigned to the caller (combine with `open=true` for the to-do list).
- `GET /issues/stats` now also returns `assignedToMe`: open issues assigned to the caller.
