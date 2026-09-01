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
- Long-term clients: **iPhone, iPad, Mac**, plus **separate** Web / Android / Windows prototypes
- MVP = daily planner (tasks, basic recurrence, timetable, sync, reminders)
- Parallel shells (2026-09-01): Web / Android / Windows. Pairing is a **sync key** issued on Apple (Settings), not email. Calendar bridges out of scope.

### Architecture (locked for now)
- **Canonical data:** Supabase (Postgres + Auth + Realtime)
- Apple clients: SwiftUI + **local SQLite/GRDB cache** synced to Supabase
- CloudKit: **not** used as database
- Domain logic (recurrence, timetable occurrences) stays **pure / testable / portable**
- Auth MVP: **Sign in with Apple** on iOS; **email + password** on Web / Android / Windows until Apple is enabled on hosted

### Why Supabase (not PocketBase / Firebase)
- Relational model fits lists/tasks/tags/schedules
- Managed Auth + Apple sign-in without self-hosting
- Realtime + RLS; Android/web attach to same API later
- PocketBase is lighter ops for a solo SQLite binary, but you’d babysit hosting and outgrow it sooner for multi-client — revisit only if Supabase free-tier/ops become painful
- Firebase: easier some mobile paths; weaker fit for relational timetable data

### Design
- **Classic Notebook** locked in light — beige paper, graphite, pastel sage + sky
- Dark appearance: **Notebook** (dimmed paper), **Morocco** (cocoa leather), or **Clothbound** (charcoal + kraft gilt). Settings → Dark appearance.
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
| iPhone nav | Tabs — Today / Calendar / Focus / Settings |
| iPad/Mac nav | Sidebar (same + Search) |
| Timetable complete | Does **not** complete a task |
| Recurrence edit MVP | Series-only |
| Overnight blocks | Not in MVP |
| Week start | **Monday** (Australian / ISO); UI locale `en_AU` |
| Calendar panes | **Day → Week → Month** (default Day) |
| Grocery lists | Name contains grocery/groceries → checklist UI; task title nudge otherwise |
| List subheadings | **Tags as soft groups** (default Group by tag ON). Few lists (Life + Groceries); classes/projects = tags |

### Sequence position
- **Now working on:** **Full dogfood** (Pomodoro shipped locally)
- **Done locally:** A–I + Phase **M** Focus / Pomodoro
- **Still manual (MVP gate):** Sign in with Apple (needs paid Apple Developer), two-device sync smoke, G8 device fire — fold into full dogfood
- Verdict: **shippable for local/personal use** with Focus timer; App Store / TestFlight wait on Apple Program + dogfood

### Post-MVP roadmap (locked 2026-08-25; habits↔Eisenhower swapped 2026-08-25 evening)
1. **Pomodoro / Focus** (Phase M — done locally)
2. **Full dogfooding** (real-week use + finish remaining MVP manual checks)
3. **Theme picker** + **calendar polish** + **NL quick-add** + **Habits**
4. **Consider widgets** (+ App Intents) after that batch proves useful
5. Later / P2: Eisenhower matrix, collab, …

### Open decisions (non-blocking)
- [x] Mac vs iOS: native multiplatform target via XcodeGen (`supportedDestinations: [iOS, macOS]`)
- [x] Local cache library: **GRDB**
- [x] P1 focus feature: **Pomodoro / Focus** first (M); **Habits** in J after dogfood
- [ ] Push: APNs via Supabase Edge / third-party later

### Explicit non-goals (for now)
- Full TickTick parity
- Collaboration/shared lists as MVP
- Flutter/RN
- CloudKit as primary database
- Multiple selectable themes in MVP
- PocketBase migration (unless Supabase blocked)
- Kanban boards

---

## Active focus

1. **Full dogfood** (incl. Apple Sign-In when enrolled, two-device sync, G8; exercise Focus)
2. Then: theme picker → calendar polish → NL quick-add → **Habits**
3. After that batch: **consider widgets**
4. Later: Eisenhower matrix, …

## Pre-start checklist

### Must decide
- [x] Backend: **Supabase**
- [x] App name: **Tickytacky**
- [x] Defaults locked (table above)
- [x] Docs aligned to API-first (this pass)
- [x] Post-MVP order: Pomodoro → dogfood → theme/calendar/NL/**Habits** → widgets later; Eisenhower deferred

### Defer
- Eisenhower matrix, collab, widgets until after the Habits batch (widgets may come right after J)

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

### 2026-08-25 (audit: security + tidy + perf)
- Security: sample seeder `#if DEBUG` only; Apple Sign-In nonce; sign-out wipes local cache; Release `ENABLE_TESTABILITY=NO`; RLS same-owner FK migration `00007`
- Perf: list/tag summary SQL aggregates; month calendar batched marks; sync dirty SQL counts/fetches
- Tidy: removed `TimetablePlaceholderView`; deduped `.task`/`.onAppear` reloads; force-unwrap cleanups

### 2026-08-25 (drop Kanban)
- Kanban removed from roadmap / non-goals

### 2026-08-25 (roadmap: Habits over Eisenhower)
- Phase J batch: theme + calendar polish + NL quick-add + **Habits** (Eisenhower moved to P2; Kanban dropped)

### 2026-08-25 (AU calendar)
- Calendar tab order **Day | Week | Month**; `AppCalendar` en_AU + Monday week start; day-before-month dates; Colour spelling in schedule editor

### 2026-08-25 (few lists + tag groups)
- Default **Group by tag** ON; `TagGrouping` prefers context tags over meta (Urgent/Waiting)
- Sample data: **Life + Groceries** only (plus Inbox); Work/MATH101/HIST200 as tags
- Browse: Tags first; Quick Add supports tags

### 2026-08-25 (grocery + subheadings)
- Grocery: list name keyword → checklist (multi-add, checked section); non-grocery task title → subtle Move to Groceries nudge
- Subheadings: no section entities — use tags (MATH101…) under a few lists (University); List menu **Group by tag**

### 2026-08-25 (day gantt)
- Calendar tab: **Week | Day | Month**; Day = hour Gantt for timetable blocks (month timeline deferred)

### 2026-08-25 (calendar week/month)
- Dropped Agenda; Calendar tab is **Week | Month** (persists last choice)

### 2026-08-25 (nav labels)
- Root tabs: **Today** (Day | Lists), **Calendar** (Agenda | Calendar), Focus, Settings

### 2026-08-25 (nav merge)
- Root tabs: **Browse** (Today | Lists), **Upcoming** (Agenda | Week), **Focus**, **Settings**
- Today + Timetable no longer separate tabs; Settings back on main bar

### 2026-09-01 (sync key)
- Apple Settings issues `TTK-…` key; Edge Function `sync-key` + table `sync_keys`
- Web/Android/Windows redeem the same key for a Supabase session
- Hosted: migration applied, function deployed (`verify_jwt` off; custom key auth)

### 2026-09-01 (hosted sync for non-Apple shells)
- Hosted API `fgdmonniblfzapdpxfxc` healthy: REST + GoTrue; email on, Apple off, confirm-email on
- MCP SQL blocked (DB password); dashboard: disable Confirm email and/or enable Apple
- Web/Android/Windows: email login + Inbox/task pull-push (`apps/_shared`)

### 2026-09-01 (parallel non-Apple shells)
- Scaffolded **Tickytacky Web** (`apps/web`), **Tickytacky Android** (`apps/android`), **Tickytacky Windows** (`apps/windows`)
- Did not change `apps/ios/` sources; index in `apps/README.md`
- Sample Today UI only; sync / shared domain later

### 2026-08-25 (Phase M Pomodoro)
- Focus / Pomodoro: `v9_focus`, FocusEngine, Focus tab, Settings durations, task link + end notification
- Next: full dogfood

### 2026-08-25 (post-MVP roadmap)
- Locked next build: **Pomodoro / Focus**, then **full dogfood**
- After dogfood: theme picker, calendar views, NL quick-add, Eisenhower matrix
- Calendar note: **potentially merge with Upcoming tab** (avoid extra root tab; open DECISION in Phase J)
- Widgets: **consider later** (not next)
- Habits deferred (Focus chosen for Phase M); SCOPE + IMPLEMENTATION_MAP synced

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
