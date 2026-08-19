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
- [ ] Subtasks / checklist items
- [ ] Lists (or projects/folders)
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

- [ ] Calendar views with tasks + timetable
- [ ] Richer recurrence (custom weekdays, end conditions)
- [ ] Filters; optional NL quick add
- [ ] Multiple timetables; conflict highlighting; drag blocks on iPad/Mac
- [ ] Habits **or** Pomodoro (pick one)
- [ ] Widgets + App Intents
- [ ] iPad/Mac polish
- [ ] Theme picker (additional token packs)

---

### P2 — Expansion

- [ ] Kanban, Eisenhower matrix
- [ ] Full habits + focus if not both done
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

1. App shell + Notebook tokens + Supabase project/schema
2. Task model + lists + Today (local cache)
3. Due dates, priorities, tags, search
4. Basic recurrence
5. Timetable + weekly view
6. Combined Today
7. Supabase auth + sync
8. Notifications
9. Calendar + widgets (P1)
10. iPad/Mac polish; themes picker; habits or focus

---

## Open decisions

_Mostly locked — see [`MEM.md`](MEM.md)._ Remaining non-blocking: exact Xcode multiplatform packaging, push pipeline details.

---

## Summary

| Tier | Intent |
|------|--------|
| **P0 MVP** | Tasks + lists + recurrence + **timetable** + Supabase sync + reminders + Notebook UI |
| **P1** | Calendar, themes picker, widgets, polish, habits *or* focus |
| **P2** | Boards, collab, Android/web, Watch, extras |
