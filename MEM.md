# Project Memory (MEM)

Living scratchpad for this repo. **Update continuously** as decisions change, work progresses, or new constraints appear.

Related docs:
- [`SCOPE.md`](SCOPE.md) — product goals & feature tiers
- [`IMPLEMENTATION_MAP.md`](IMPLEMENTATION_MAP.md) — work map & sequence
- [`DESIGN.md`](DESIGN.md) — Classic Notebook design language

---

## How to use this file

1. After any meaningful chat/decision → append or edit here the **same day**
2. Prefer editing **Current truth** in place; use **Log** for history
3. If SCOPE or the implementation map disagree with this file, **fix them** and note it in the log
4. Keep entries short; link to files/PRs instead of pasting essays

---

## Current truth

### Product
- **App name:** Tickytacky
- **Bundle ID (working):** `app.tickytacky.ios` (Mac may share multiplatform ID — confirm in Xcode)
- Apple-first TickTick-style planner: tasks + **recurring timetable**
- Long-term clients: **iPhone, iPad, Mac**, then **Android + web**
- MVP = daily planner (tasks, basic recurrence, timetable, sync, reminders)

### Architecture (locked for now)
- **Canonical data:** Supabase (Postgres + Auth + Realtime)
- Apple clients: SwiftUI + **local SQLite/GRDB cache** synced to Supabase
- CloudKit: **not** used as database
- Domain logic (recurrence, timetable occurrences) stays **pure / testable / portable**
- Auth MVP: **Sign in with Apple** via Supabase Auth (email/Google later)

### Why Supabase (not PocketBase / Firebase)
- Relational model fits lists/tasks/tags/schedules
- Managed Auth + Apple sign-in without self-hosting
- Realtime + RLS; Android/web attach to same API later
- PocketBase is lighter ops for a solo SQLite binary, but you’d babysit hosting and outgrow it sooner for multi-client — revisit only if Supabase free-tier/ops become painful
- Firebase: easier some mobile paths; weaker fit for relational timetable data

### Design
- **Classic Notebook** locked — beige paper, graphite, pastel sage + sky
- Theme picker later; `ThemeTokens` API in code
- See [`DESIGN.md`](DESIGN.md)

### Defaults locked
| Item | Choice |
|------|--------|
| UI | SwiftUI |
| Min OS | iOS/iPadOS 18, macOS 15 |
| Local cache | GRDB/SQLite |
| Soft-delete | Yes |
| Conflicts | Last-write-wins per record |
| Overdue | Show in Today |
| iPhone nav | Tabs |
| iPad/Mac nav | Sidebar |
| Timetable complete | Does **not** complete a task |
| Recurrence edit MVP | Series-only |
| Overnight blocks | Not in MVP |
| Week start | User setting (system-friendly default) |

### Sequence position
- **Now working on:** Manual MVP gate (Secrets, two-device sync, G8 device, TestFlight/dogfood)
- **Done locally:** A–I code + ship-readiness sync/data fixes (UUID case, inbox reconcile, LWW dirty-local, account wipe, v8 id normalize)
- **Cloud:** Apply `…00005` on remote before trusting LWW
- Verdict: **ready for personal dogfood / internal TestFlight** after Secrets + signing; **not** App Store public until two-device + G8 pass

### Open decisions (non-blocking)
- [x] Mac vs iOS: native multiplatform target via XcodeGen (`supportedDestinations: [iOS, macOS]`)
- [x] Local cache library: **GRDB**
- [ ] Push: APNs via Supabase Edge / third-party later

### Explicit non-goals (for now)
- Full TickTick parity
- Collaboration/shared lists as MVP
- Flutter/RN
- CloudKit as primary database
- Multiple selectable themes in MVP
- PocketBase migration (unless Supabase blocked)

---

## Active focus

1. Wire Secrets + Sign in with Apple; apply remote `…00005`
2. Two-device sync smoke + G8 physical reminder fire
3. TestFlight + ~7-day dogfood (`apps/ios/MVP_HARDENING.md`)

## Pre-start checklist

### Must decide
- [x] Backend: **Supabase**
- [x] App name: **Tickytacky**
- [x] Defaults locked (table above)
- [x] Docs aligned to API-first (this pass)

### Defer
- Theme picker, habits/Pomodoro, widgets, Kanban, collab, NL quick-add

---

## Gotchas & lessons

- LLMs are bad at time estimates → order + priority only (`IMPLEMENTATION_MAP` §11)
- CloudKit ≠ path to Android/web
- Timetable blocks are first-class entities
- Occurrences computed; exceptions stored
- iOS pending notification ~64 cap
- Prefer Supabase over PocketBase for multi-client + managed Apple auth

---

## Doc sync checklist

- [x] `MEM.md` Current truth updated
- [x] `SCOPE.md` matches
- [x] `IMPLEMENTATION_MAP.md` matches
- [x] `DESIGN.md` name/theme references
- [x] Log entry added

---

## Log

Newest first.

### 2026-08-20 (cloud storage compact)
- Migration `20260819000006_storage_compact.sql`: drop unused cols, nullable recurrence, smallints, text caps, purge_soft_deleted()
- Client SyncMapper omits empty strings / unused fields; SyncMapping.md + supabase README updated

### 2026-08-19 (local Phase I code)
- I1–I5, I9: a11y + Dynamic Type, iPad split selection, Mac min window + delete key, P0 empty states
- Docs: `apps/ios/MVP_HARDENING.md` (manual TestFlight/Privacy/G8/two-device + remote `…00005`), `apps/ios/BUGS.md` for P1
- Skipped: realtime, TestFlight upload, Privacy filing, schema changes

### 2026-08-19 (local Phase H client)
- Sign in with Apple → Supabase (`AuthService` + Settings); offline CRUD without account
- `SyncEngine` pull/push for lists/tasks/subtasks/tags/task_tags/schedules/blocks/exceptions; LWW via `updated_at`; dirty via `synced_at` (`v7_sync`)
- Mapping notes in `apps/ios/Tickytacky/Data/Sync/SyncMapping.md` (reminders local-only; weekday/due/priority/recurrence maps)
- Client-needed cloud fix: `supabase/migrations/20260819000005_lww_updated_at.sql` (preserve client `updated_at`)
- Gaps: realtime subscribe deferred; H8 large-dataset smoke optional/manual

### 2026-08-19 (local Phase G)
- Local notifications: `ReminderRequestBuilder` + `ReminderScheduler`, Settings status, task/block reminders, ~64 budget, deep links (`tickytacky://`), foreground banners
- Migration `v6_reminders` (`reminder_offsets_json` on tasks); blocks keep `reminder_minutes_before`
- G8 device fire still manual (Simulator limited)

### 2026-08-19 (local Phase A+B)
- Branch `local/phase-a-foundation`: XcodeGen multiplatform app in `apps/ios/`
- Phase A: ThemeTokens/Notebook, GRDB cache, Inbox seed, tab/split shell, Supabase config stub
- Phase B: tasks/subtasks/lists CRUD, Today (overdue+due), Upcoming 7d, Browse, quick add, task detail
- Verified: iPhone 17 sim + Mac builds; Inbox row in SQLite
- Cloud parallel: `cursor/setup-supabase-dev-env-9475` owns `supabase/`

### 2026-08-19 (remote)
- GitHub remote: `git@github.com:SlipperySon/TickyTacky.git`

### 2026-08-19 (decisions lock)
- App name: **Tickytacky** (`app.tickytacky.ios`)
- Backend: **Supabase** (kept; PocketBase lighter but worse multi-client fit)
- Locked all listed defaults; design Classic Notebook unchanged
- Aligned SCOPE + IMPLEMENTATION_MAP away from CloudKit-canonical

### 2026-08-19 (earlier)
- Design locked Classic Notebook; MEM created; API-first pivot; order/priority roadmap
