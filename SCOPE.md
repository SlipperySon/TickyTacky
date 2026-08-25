# Tickytacky — Scope & Goals

Apple-first personal planner (**Tickytacky**) for **iPhone**, **iPad**, and **Mac**, with **Android + web** planned later.

**Stack:** SwiftUI clients · local SQLite/GRDB cache · **Supabase** (Postgres + Auth + Realtime) as source of truth · Classic Notebook design ([`DESIGN.md`](DESIGN.md)).

---

## Product vision

A fast, dense personal productivity app in the spirit of TickTick — tasks, planning, and recurring schedules — with a cozy classic-notebook look. Apple ships first; the backend is multi-client ready.

**Not a goal (v1):** Android/web UI, full TickTick parity, collaboration.

---

## Goals

1. Replace a basic TickTick / Reminders / calendar workflow for personal use.
2. Ship an **MVP** you can use daily, then grow into a Tickytacky daily driver.
3. Stay Apple-native on clients: widgets, App Intents / Shortcuts, system notifications (P1+).
4. **Supabase** as canonical store so Android/web can attach later without a data rewrite.
5. Optimize for speed and clarity over feature count.
6. One shipping theme (**Classic Notebook**); selectable themes later.

---

## Platforms

| Platform | Priority | Notes |
|----------|----------|--------|
| iPhone   | P0       | Primary target |
| iPad     | P1       | Adaptive navigation, split view |
| Mac      | P1       | Real desktop UX |
| Android  | P2       | Same Supabase API |
| Web      | P2       | Same Supabase API |

---

## Feature scope

### P0 — MVP (must ship)

#### Tasks
- [ ] Create, edit, complete, delete tasks
- [ ] Task title, notes/description
- [ ] Due date (and optional due time)
- [ ] Priority levels
- [x] Subtasks / checklist items
- [x] Grocery checklist lists (name keyword) + task-title nudge
- [x] Lists (or projects/folders)
- [x] Soft list subheadings via **Group by tag** (classes as tags)
- [ ] Tags
- [ ] Search
- [ ] Today view (includes overdue)
- [ ] Upcoming / next-N-days view
- [ ] Completed / archive view (basic)

#### Recurrence (basic)
- [ ] Daily / weekly / monthly / yearly recurring tasks
- [ ] Simple “every N days/weeks” rules
- [ ] Clear next-occurrence behavior after completion
- [ ] Edit series only in MVP (no “this occurrence only” for tasks yet)

#### Scheduling & timetable (recurring schedule)
First-class **timetable** blocks — not just task due dates.

- [ ] Create recurring schedule blocks (class, workout, deep work, etc.)
- [ ] Day-of-week + time range (start/end); no overnight spans in MVP
- [ ] Weekly timetable view
- [ ] One-off exceptions (skip / reschedule a single occurrence)
- [ ] Optional link to list; show alongside tasks on Today
- [ ] Completing/skipping a slot does **not** auto-complete a task

#### Sync & accounts
- [ ] Sign in with Apple (Supabase Auth)
- [ ] Sync tasks, lists, tags, and schedule across Apple devices via Supabase
- [ ] Offline cache with later sync (GRDB/SQLite)
- [ ] Soft-delete + last-write-wins conflict policy

#### Notifications
- [ ] Local reminders for due tasks
- [ ] Optional reminders for upcoming timetable blocks

#### App shell
- [ ] Native SwiftUI UI (iPhone tabs; iPad/Mac sidebar when polished)
- [ ] Classic Notebook theme tokens
- [ ] Sensible empty states and basic settings
- [ ] System light/dark (Notebook mapping)

---

### P1 — Daily driver (post-MVP)

**Ordered (2026-08-25):**

1. **Pomodoro / Focus** (chosen over habits for Phase M)
2. **Full dogfooding** (real-week use; finish remaining MVP manual checks)
3. Then, as a batch:
   - [ ] Theme picker (additional token packs)
   - [ ] Calendar views with tasks + timetable — **prefer merging into Upcoming** (toggle / hybrid) over a new root tab; decide after dogfood
   - [ ] Optional NL quick add
   - [ ] Eisenhower matrix
4. After that batch: **consider** widgets + App Intents

Also in P1 when capacity allows (not sequenced above):
- [ ] Richer recurrence (custom weekdays, end conditions)
- [ ] Filters
- [ ] Multiple timetables; conflict highlighting; drag blocks on iPad/Mac
- [ ] iPad/Mac polish

---

### P2 — Expansion

- [ ] Habits (if still wanted after Focus)
- [ ] Kanban
- [ ] Widgets + App Intents (if not done after the P1 batch)
- [ ] Attachments, analytics
- [ ] Collaboration / shared lists
- [ ] Android app, web app
- [ ] Apple Watch, Live Activities
- [ ] EventKit sync (careful)

---

### Explicit non-goals (for now)

- Flutter / React Native single UI
- CloudKit as primary database
- Team/org workspaces
- Marketplace / social

---

## Success criteria

### MVP
Run your week from Tickytacky alone for personal tasks, recurring routines, and a fixed weekly timetable — synced across at least two Apple devices, reminders trustworthy enough to rely on.

### Daily driver
Prefer Tickytacky over TickTick / Reminders for day-to-day planning.

---

## Suggested build order

1. App shell + Notebook tokens + Supabase project/schema *(done)*
2. Task model + lists + Today (local cache) *(done)*
3. Due dates, priorities, tags, search *(done)*
4. Basic recurrence *(done)*
5. Timetable + weekly view *(done)*
6. Combined Today *(done)*
7. Supabase auth + sync *(done locally; Sign in with Apple needs Apple Developer)*
8. Notifications *(done; G8 device fire in dogfood)*
9. **Pomodoro / Focus**
10. **Full dogfood**
11. Theme picker + calendar views + NL quick-add + Eisenhower matrix
12. Consider widgets (+ App Intents); then polish / P2 as needed

---

## Open decisions

_Mostly locked — see [`MEM.md`](MEM.md)._ Remaining non-blocking: push pipeline details; whether widgets ship after the P1 batch.

---

## Summary

| Tier | Intent |
|------|--------|
| **P0 MVP** | Tasks + lists + recurrence + **timetable** + Supabase sync + reminders + Notebook UI |
| **P1** | Pomodoro → dogfood → theme + calendar + NL + Eisenhower → *then consider* widgets |
| **P2** | Habits (optional), Kanban, collab, Android/web, Watch, extras |
