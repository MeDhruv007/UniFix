# FixMyCampus Screens v2 — implementation brief

Source: Claude Design project "FixMyCampus Screens v2" (light theme only).

- `screens-v2.html` — the decoded design file. **Exact CSS values live here** (sizes, radii, colours, font sizes/weights, copy). Each phone is a `<div id="NN">` block; sample data is in the `<script>` at the end.
- `NN-*.png` — a rendered crop of each phone (2× scale; the phone frame is 360×780 CSS px). Use them to check layout.

| # | Screen | Crop |
|---|---|---|
| 01 | Sign in | `01-sign-in.png` |
| 02 | Register | `02-register.png` |
| 03 | Student home | `03-home.png` |
| 04 | Campus feed | `04-campus-feed.png` |
| 05 | Report form | `05-report-form.png` |
| 06 | Submitted | `06-submitted.png` |
| 07 | Issue detail | `07-issue-detail.png` |
| 08 | My reports | `08-my-reports.png` |
| 09 | Resolution feedback | `09-resolution-feedback.png` |
| 10 | Admin overview | `10-admin-overview.png` |
| 11 | Triage queue | `11-triage-queue.png` |
| 12 | Update issue (bottom sheet) | `12-update-issue-sheet.png` |
| 13 | Mark resolved | `13-mark-resolved.png` |
| 14 | Empty — filtered feed | `14-empty-filtered-feed.png` |
| 15 | Offline — upload failed | `15-offline-upload-failed.png` |
| 16 | No access | `16-no-access.png` |

## Foundations (already built — use them, don't duplicate)

- Theme: `lib/core/theme/app_theme.dart` (Plus Jakarta Sans bundled, light only). Inputs are already 54px filled pills; `FilledButton` is the black pill; `OutlinedButton` the outlined pill.
- Tokens: `lib/core/theme/app_colors.dart` → `AppColors`, `AppRadii`, `AppSizes`. Never hard-code a hex that has a token.
- Issue styling: `lib/core/theme/issue_styles.dart` → `category.code` (EL, PL…), `category.swatch`, `category.chartColor`, `status.pillColor`, `priority.cardColor`, `priority.pill`.
- Widgets: `import '…/core/widgets/ds/ds.dart';` gives `PrimaryPillButton` (+`PillBadge` trailing), `SecondaryPillButton`, `CircleIconButton`, `DsChip` (with `count` badge), `DsPill`, `InfoBanner`, `SectionLabel`, `DsTopBar`, `DsPageHeader`, `DsSearchField`, `DsBottomNav`/`DsNavItem` (center "+" via `onCenterTap`), `CodeAvatar` (+`initialsOf`), `StripedPlaceholder`, `ProgressRing`, `StepBar`. You may add new shared widgets to `lib/core/widgets/ds/` only in a **new file you own** named after your area (e.g. `ds_admin.dart`) — do not edit the existing ds files; ask the lead if one needs a change.
- Existing app widgets you can reuse/restyle inside your own area: `IssuePhoto` (authenticated image), `IssueTimeline`, `StatusChip`/`PriorityChip`, `IssueFeedView`, `IssueCard`.

## Data available (no new backend work needed)

- `IssueRepository` (`lib/features/reports/domain/repositories/issue_repository.dart`):
  - `watchIssues(filter:, limit:)` with `IssueFilter(status, category, reporterId, query, openOnly, priority, assigned, sort)`; `watchIssue`, `watchUpdates`, `createIssue`, `photo(path)`.
  - Admin: `updateStatus`, `updatePriority`, `assignToMe`, `assignTo(id, staffId|null)`, `listStaff()`, `addResolutionPhotos`.
  - Stats: `stats({mine})`, `watchStats({mine})` → `IssueStats` (counts per status, `open`, `urgent`, `unassigned`, `createdLast24h`, `resolvedThisWeek`, `avgResolutionHours`, `openByCategory`). Students may only call with `mine: true`.
- `Issue` has `displayCode` (FMC-0483), `progressStep` (1–3 for the ring), `assignedToName`, `reporterDisplayName`. `IssueUpdate` has `actorName`.
- `IssueListBloc` events: `IssueListSubscribed(filter)`, `IssueListStatusFilterChanged`, `IssueListCategoryFilterChanged`, `IssueListFilterChanged((f) => f.copyWith(...))`, `IssueListQueryChanged(text)` (debounced), `IssueListLoadMoreRequested`, `IssueListRefreshRequested`.
- Session: `AuthBloc` (`state.user` → `AppUser` with `displayName`, `email`, `department`, `role`, `isAdmin`).
- `CampusBuildings.all` / `.nameOf(id)` for building names; departments are free text today.

## Rules

- Match the design closely (spacing, sizes, radii, copy), but **never fake data or features**:
  - Omit the notification bell (no notifications feature), the share icon, and "Near me" (no location) — use "All" for the first home chip.
  - Replace sample people/numbers with real data (e.g. "Hello, <first name>").
  - The design's "Ask reporter to confirm the fix" checkbox: reporters already get the feedback prompt on resolved issues — show it as a non-interactive info line, not a checkbox.
- Every list/screen still needs loading, empty, error and offline states (existing `LoadingView`/`EmptyView`/`ErrorView` or a restyled equivalent).
- Accessibility: 48px touch targets, tooltips/semantics on icon-only buttons, text must not rely on colour alone.
- Keep architecture: widgets → BLoC/Cubit → repository. No Dio/HTTP in widgets. New cubits get registered in `lib/injection_container.dart` **only by the lead** — report the exact registration snippet instead of editing it.
- Run `flutter analyze` (clean) and `flutter test` (all pass) before finishing. Other agents edit in parallel; ignore transient errors in files you don't own. Don't run the app/emulator (the lead does visual QA), but do write widget tests for new screens (pump with mocked repositories via mocktail) that at least render each state without overflow errors at 360×780.
