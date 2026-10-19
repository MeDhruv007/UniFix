# UniFix

Campus maintenance reporting for students, with a triage workflow for facilities admins. Flutter (Android) app + Node/Express REST API + PostgreSQL, run with Docker.

```
Flutter app ──Dio/JSON──▶ backend/ (Express API) ──▶ PostgreSQL
                              └── photo files (Docker volume)
```

- Design: `../FixMyCampus_Architecture_Design.md`
- API contract (app ⇄ server): [`docs/API.md`](docs/API.md)
- Backend: [`backend/README.md`](backend/README.md)

## Run it

1. **Backend** (needs Docker Desktop running):
   ```
   cd backend
   cp .env.example .env      # then set POSTGRES_PASSWORD and JWT_SECRET (32+ chars)
   docker compose up --build
   ```
   API: http://localhost:3000/api/v1 (health: `/health`).
2. **App** on the Android emulator:
   ```
   flutter run
   ```
   The emulator reaches your PC at `10.0.2.2`, which is the default. For a real phone on the same Wi-Fi:
   `flutter run --dart-define=API_BASE_URL=http://<PC LAN IP>:3000/api/v1`
3. **Make an admin**: register in the app, then
   ```
   docker compose exec api npm run make-admin -- you@adit.ac.in
   ```
   The app picks up the new role within a minute (or on next launch).

## Features

| Student | Admin |
|---|---|
| Register / sign in / reset password | Status counts dashboard |
| Report an issue with up to 3 photos | Queue with status/category filters |
| Campus feed + "My reports", filters, paging | Status transitions with notes (resolve requires a note) |
| Issue details with history timeline | Priority, "assign to me", resolution photos |
| "Is it fixed?" feedback on resolved reports | |
| Profile (name, department) | Profile |

Lists refresh every 15 s and immediately after your own changes (the API has no push channel).

## Code layout

Feature-first clean architecture (`lib/features/<feature>/{data,domain,presentation}`), BLoC/Cubit for state, GetIt for DI (`lib/injection_container.dart`), go_router with role-aware guards (`lib/core/routing/`), Dio client with token interceptor (`lib/core/network/`). Repositories throw user-safe `Failure`s (`lib/core/errors/`).

## Checks

```
flutter analyze
flutter test
```
