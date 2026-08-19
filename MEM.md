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
- **Now working on:** seq 0–1 — decisions locked; foundation next
- Next: Xcode multiplatform app + Supabase project/schema skeleton

### Open decisions (non-blocking)
- [ ] Exact Mac bundle / Catalyst vs native multiplatform target setup in Xcode
- [ ] GRDB vs raw SQLite wrapper library choice when coding cache
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

1. Scaffold Tickytacky iOS/macOS app + Supabase schema
2. ThemeTokens (Notebook only) + app shell
3. Phase B — local tasks CRUD against cache, then wire Supabase

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

### 2026-08-19 (backend schema — cloud)
- Landed initial Supabase schema as migrations (`supabase/migrations/`): lists, tasks, subtasks, tags, task_tags, schedules, schedule_blocks, schedule_exceptions
- Conventions: `user_id`-scoped rows, RLS (owner-only) forced on all tables, `updated_at` trigger (LWW), `deleted_at` soft-delete
- Embedded recurrence on `tasks` (series-only MVP); timetable blocks first-class
- `seed.sql`: demo user (`demo@tickytacky.app` / `tickytacky`) + sample lists/tasks/timetable
- Validated locally via `supabase db reset` + RLS isolation tests (Auth signup/login → PostgREST)
- Still open (local/client): Sign in with Apple wiring, SyncEngine — Phase H client half

### 2026-08-19 (remote)
- GitHub remote: `git@github.com:SlipperySon/TickyTacky.git`

### 2026-08-19 (decisions lock)
- App name: **Tickytacky** (`app.tickytacky.ios`)
- Backend: **Supabase** (kept; PocketBase lighter but worse multi-client fit)
- Locked all listed defaults; design Classic Notebook unchanged
- Aligned SCOPE + IMPLEMENTATION_MAP away from CloudKit-canonical

### 2026-08-19 (earlier)
- Design locked Classic Notebook; MEM created; API-first pivot; order/priority roadmap
