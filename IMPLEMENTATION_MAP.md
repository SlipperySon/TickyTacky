# Implementation Map

Extremely detailed breakdown of everything required to build **Tickytacky** — defined in [`SCOPE.md`](SCOPE.md) and [`MEM.md`](MEM.md).

This is the master work map: architecture → data → domain → UI → sync → notifications → platforms → release → post-MVP → **ordered roadmap**.

Use checkboxes to track progress. Prefer finishing an entire **phase** before starting the next unless a dependency forces otherwise.

**Order & priority** live in [§11](#11-order--priority-roadmap). No calendar/hour estimates — sequence and priority only (LLMs are bad at time estimates).

**Canonical backend:** Supabase (not CloudKit). **Design:** Classic Notebook ([`DESIGN.md`](DESIGN.md)).

---

## Build environments (cloud vs local)

| Environment | What it builds | Notes |
|-------------|----------------|-------|
| **Cloud** — Linux Cloud Agent | `supabase/`: schema, RLS, auth config, seed, Edge Functions | Apple frameworks cannot compile here |
| **Local** — macOS + Xcode | Entire SwiftUI client in `apps/ios/` | Not buildable on Linux |

| Phase | Environment |
|-------|-------------|
| A–G | **Local** |
| H (schema/RLS/auth/seed) | **Cloud** |
| H (Sign in with Apple UI, SyncEngine) | **Local** |
| I+ | **Local** |

---

## Legend

| Tag | Meaning |
|-----|---------|
| `BLOCKER` | Must finish before dependent work |
| `DECISION` | Needs a product/tech choice before coding |
| `RISK` | Easy to get wrong; budget extra time |
| `APPLE` | Needs entitlements, capabilities, or device testing |
| `P0` / `P1` / `P2` | Priority tier from scope |

---

## 0. Locked decisions

| # | Decision | Choice | Status |
|---|----------|--------|--------|
| D1 | UI framework | SwiftUI | Locked |
| D2 | Local persistence | GRDB / SQLite **cache** | Locked |
| D3 | Sync / canonical store | **Supabase** (Postgres + Auth + Realtime) | Locked |
| D4 | App shape | Multiplatform (iOS + macOS); polish iPhone first | Locked |
| D5 | Timetable model | First-class `ScheduleBlock` entities, **not** tasks | Locked |
| D6 | Completing a timetable slot | Does **not** auto-complete a task; skip/exception only | Locked |
| D7 | Auth | Sign in with Apple via Supabase Auth | Locked |
| D8 | Min OS | iOS 18 / iPadOS 18 / macOS 15 | Locked |
| D9 | Product name / bundle | **Tickytacky** / `app.tickytacky.ios` | Locked |
| D10 | Habit vs Pomodoro (P1) | **Pomodoro / Focus first**; habits deferred | Locked |
| D11 | Design theme | Classic Notebook; theme picker later | Locked |
| D12 | Soft-delete | Yes | Locked |
| D13 | Conflicts | Last-write-wins per record | Locked |
| D14 | Overdue in Today | Yes | Locked |

### Output of this section
- [x] D1–D14 locked (see also `MEM.md`)
- [x] Product name + bundle ID chosen
- [ ] Git repo initialized (if not already)
- [ ] This map kept in sync with `MEM.md` / `SCOPE.md`

---

## 1. System architecture map

```text
┌─────────────────────────────────────────────────────────────────┐
│                         App Targets                              │
│  iOS App (iPhone/iPad)  │  macOS App  │  Widgets  │  (Watch P2) │
└─────────────┬───────────────────┬─────────────┬─────────────────┘
              │                   │             │
              ▼                   ▼             ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Presentation (SwiftUI)                       │
│  Navigation · Views · ThemeTokens (Notebook) · App Intents      │
└─────────────────────────────┬───────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────┐
│                     Domain / Services                            │
│  TaskService · ListService · TagService · RecurrenceEngine       │
│  ScheduleService · OccurrenceGenerator · ReminderScheduler       │
│  SearchIndexer · TodayAssembler · SyncEngine                     │
└─────────────────────────────┬───────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────┐
│                     Local cache                                  │
│  GRDB / SQLite · migrations · seed                               │
└─────────────────────────────┬───────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────┐
│                     Backend / System                             │
│  Supabase (Postgres, Auth, Realtime, RLS)                        │
│  UNUserNotificationCenter · WidgetKit · AppIntents (P1)          │
└─────────────────────────────────────────────────────────────────┘
```

### Architectural rules
- [ ] Keep SwiftUI views thin; put recurrence/schedule math in pure Swift domain types (`RISK`)
- [ ] Never compute “today’s occurrences” only in views — centralize in `OccurrenceGenerator`
- [ ] Supabase is source of truth; local DB is a cache — tolerate brief divergence (`RISK`)
- [ ] Prefer value types for recurrence rules and timetable expansion results
- [ ] All colors via `ThemeTokens` (Notebook only in MVP)
- [ ] Soft-delete + `updated_at` on synced rows for LWW

---

## 2. Xcode project & repo bootstrap

### 2.1 Repository
- [ ] Initialize git (if empty)
- [ ] Add `.gitignore` for Xcode/Swift (DerivedData, `xcuserdata`, `.DS_Store`, etc.)
- [ ] Keep `SCOPE.md` + this map at repo root
- [ ] Optional: `README.md` with build instructions only (no marketing fluff)

### 2.2 Xcode project (`BLOCKER`)
- [ ] Create multiplatform App project named **Tickytacky** (iOS + macOS)
- [ ] Set deployment targets (iOS 18 / macOS 15)
- [ ] Bundle identifier `app.tickytacky.ios` (adjust Mac if needed)
- [ ] Add Supabase Swift package dependency
- [ ] Add GRDB (or chosen SQLite layer)
- [ ] Configure Sign in with Apple capability
- [ ] Reserve App Group for widgets later
- [ ] Configure signing teams for iPhone + Mac
- [ ] Verify run on: iPhone simulator, iPad simulator, Mac destination

### 2.3 Folder structure (suggested)
```text
App/
  AppEntry/
  AppShell/          # Tab/split navigation, settings
  Features/
    Today/
    Tasks/
    Lists/
    Tags/
    Search/
    Schedule/        # Timetable
    Calendar/        # P1
    HabitsOrFocus/   # P1
  Domain/
    Models/          # Pure domain types
    Recurrence/
    Schedule/
    Reminders/
    Search/
  Data/
    GRDB/
    Persistence/
    Migrations/
    Sync/            # Supabase sync engine
  DesignSystem/      # ThemeTokens, Notebook
  Resources/
Widgets/             # P1
Shared/              # Models/constants shared with widgets
```

- [ ] Create folder groups matching structure
- [ ] Add empty feature modules/files as placeholders **or** grow organically — pick one style and stick to it

### 2.4 Design system skeleton
- [ ] Define color tokens (list colors, priority colors, schedule block colors)
- [ ] Define typography scale (avoid default “AI generic” look; choose a deliberate SF / custom pairing)
- [ ] Shared components: `TaskRow`, `PriorityIndicator`, `TagChip`, `EmptyState`, `SectionHeader`
- [ ] Accessibility: Dynamic Type, VoiceOver labels on custom controls from day one

---

## 3. Domain model map (data layer)

All P0 entities below are required unless marked optional.

### 3.1 Core entities

#### `TaskItem` (`P0`)
Fields:
- [ ] `id: UUID`
- [ ] `title: String`
- [ ] `notes: String?`
- [ ] `isCompleted: Bool`
- [ ] `completedAt: Date?`
- [ ] `createdAt: Date`
- [ ] `updatedAt: Date`
- [ ] `dueDate: Date?` (date-only semantics need care — store start-of-day in calendar TZ or date components) (`RISK`)
- [ ] `dueTime: DateComponents?` / `hasDueTime: Bool`
- [ ] `priority: Priority` (none / low / medium / high / urgent — finalize enum)
- [ ] `sortOrder: Int` (or fractional index later)
- [ ] `list: TaskList?` relationship
- [ ] `tags: [Tag]` relationship
- [ ] `subtasks: [Subtask]` relationship
- [ ] `recurrenceRule: RecurrenceRule?` (embedded or related)
- [x] `reminderOffsets: [TimeInterval]` or dedicated `Reminder` entities
- [ ] Soft-delete (`deleted_at`) — **yes** (locked)

Behaviors to support:
- [ ] Complete / uncomplete
- [ ] Reschedule due date
- [ ] Move between lists
- [ ] Attach/detach tags
- [ ] Apply recurrence on complete (`RISK`)

#### `Subtask` (`P0`)
- [ ] `id`, `title`, `isCompleted`, `sortOrder`, parent `TaskItem`

#### `TaskList` (`P0`)
- [ ] `id`, `name`, `color`, `icon?`, `sortOrder`, `isInbox: Bool`
- [ ] Relationship: tasks
- [ ] Guard: exactly one Inbox (or system default list) (`RISK`)

#### `Tag` (`P0`)
- [ ] `id`, `name`, `color?`
- [ ] Unique name constraint (case-insensitive policy) (`DECISION`)
- [ ] Many-to-many with tasks

#### `RecurrenceRule` (`P0`, `RISK`)
Store as structured data, not free text.

- [ ] `frequency: daily | weekly | monthly | yearly`
- [ ] `interval: Int` (every N)
- [ ] `byWeekdays: [Weekday]?` (P1 for custom; MVP may allow simple weekly)
- [ ] `monthDay` / `weekOfMonth` rules (P1+)
- [ ] `startDate`
- [ ] `endDate?` / `occurrenceCount?` (P1; MVP can omit end)
- [ ] Timezone policy documented (`RISK`)

Engine requirements:
- [ ] Given rule + anchor, compute next due date after completion
- [ ] Expand occurrences for a date range (for Upcoming / Calendar)
- [ ] Never mutate historical completed instances incorrectly

**Recurrence completion policy (`DECISION`, `BLOCKER` for engine):**
- Recommended MVP: completing a recurring task **moves due date to next occurrence** and leaves a completion log **or** creates a completed instance record
- Document chosen approach in code comments + this map

#### `Schedule` / `Timetable` (`P0`)
Container for a named timetable.

- [ ] `id`, `name` (e.g. “Semester 1”, “Work Week”)
- [ ] `isActive: Bool` (MVP may allow one active)
- [ ] `timezone` or inherit device TZ (`DECISION`)
- [ ] `color?`
- [ ] Relationship: blocks

#### `ScheduleBlock` (`P0`)
Recurring weekly (MVP) time block.

- [ ] `id`
- [ ] `title` (e.g. “Deep Work”, “CHEM 101”)
- [ ] `notes?`
- [ ] `weekday: Weekday` (or multiple weekdays — `DECISION`: one row per weekday vs multi-day)
- [ ] `startTime: DateComponents` (hour/minute)
- [ ] `endTime: DateComponents`
- [ ] Validation: end > start; no midnight-spanning in MVP **or** support overnight (`DECISION`, `RISK`)
- [ ] `color`
- [ ] Optional `list: TaskList?` link
- [ ] Optional `tag: Tag?` link
- [x] `reminderMinutesBefore: Int?`
- [ ] Parent `Schedule`

#### `ScheduleException` (`P0`)
One-off skip/move for a generated occurrence.

- [ ] `id`
- [ ] `block: ScheduleBlock`
- [ ] `originalStart: Date` (occurrence identity)
- [ ] `type: skip | reschedule`
- [ ] `newStart?`, `newEnd?` if reschedule
- [ ] Notes optional

#### `ScheduleOccurrence` (computed, not stored — recommended)
- [ ] Pure value type produced by `OccurrenceGenerator`
- [ ] Fields: `blockID`, `title`, `start`, `end`, `isExceptionApplied`, `color`
- [ ] Used by Today, Weekly Timetable, reminders

#### Supporting / later entities
- [ ] `CompletionLog` (optional P0 if recurrence needs history)
- [ ] `Habit` / `FocusSession` (P1)
- [ ] `Attachment` (P2)
- [ ] `SharedList` metadata (P2)

### 3.2 Indexes & query needs
- [ ] Tasks by `dueDate` range
- [ ] Incomplete tasks for Today (due ≤ today OR due today with time)
- [ ] Overdue separate from Today (`DECISION`: show overdue in Today?)
- [ ] Tasks by list
- [ ] Tasks by tag
- [ ] Full-text-ish search on title/notes (simple `contains` MVP OK)
- [ ] Active schedule blocks for weekday
- [ ] Exceptions by block + date range

### 3.3 Migrations
- [ ] Plan lightweight migration path from day one
- [ ] Version schema; never silently wipe user data in TestFlight builds
- [ ] Seed: Inbox list + sample timetable (DEBUG only)

---

## 4. Domain services map

### 4.1 `TaskService`
- [ ] create / update / delete
- [ ] complete / uncomplete (with recurrence side effects)
- [ ] reorder within list
- [ ] bulk move / bulk complete (nice-to-have P1)
- [ ] validate non-empty title

### 4.2 `ListService`
- [ ] create / rename / recolor / reorder / delete
- [ ] delete list policy: move tasks to Inbox vs block delete (`DECISION`)
- [ ] ensure Inbox exists on first launch

### 4.3 `TagService`
- [ ] create / rename / delete
- [ ] attach / detach to tasks
- [ ] merge tags? (P1)

### 4.4 `RecurrenceEngine` (`RISK`, `BLOCKER` for recurring tasks)
- [ ] Unit tests first for date math
- [ ] `nextDate(after:rule:calendar:)`
- [ ] `occurrences(from:to:rule:)`
- [ ] Handle DST transitions (`RISK`)
- [ ] Handle month-end (Jan 31 + monthly) (`RISK`)
- [ ] Document unsupported rules in MVP

### 4.5 `ScheduleService` + `OccurrenceGenerator` (`P0`, `RISK`)
- [ ] CRUD for Schedule + ScheduleBlock + Exception
- [ ] `occurrences(for:date:activeSchedules:)`
- [ ] `occurrences(for:weekStarting:)`
- [ ] Apply exceptions
- [ ] Detect invalid blocks
- [ ] P1: conflict detection (overlaps)

### 4.6 `TodayAssembler`
- [x] Merge overdue tasks, due-today tasks, undated pinned? (no pins in MVP unless added)
- [x] Merge today’s schedule occurrences
- [x] Stable sort: timetable by start time; tasks by priority then due time then sortOrder (`DECISION`)
- [x] Section model for UI

### 4.7 `ReminderScheduler` (`APPLE`, `RISK`)
- [x] Request notification permission UX
- [x] Schedule local notifications for task due reminders
- [x] Schedule notifications for upcoming timetable blocks
- [x] Reschedule on edit/delete/complete
- [x] Cap pending notifications (iOS limit ~64) — prioritize soonest (`RISK`)
- [x] Clear delivered notifications appropriately
- [x] Handle timezone / travel changes on foreground

### 4.8 `SearchService`
- [ ] Query tasks by title/notes
- [ ] Optional: search lists, tags, schedule block titles
- [ ] Debounced search UI

---

## 5. Navigation & screen map

### 5.1 Information architecture (iPhone)

**Locked 2026-08-25:** four root tabs.

```text
Tab / root
├── Today
│   ├── Day (default)
│   └── Lists (+ Tags) — browse lives here
├── Calendar
│   ├── Week (strip + day list)
│   ├── Day (hour Gantt bars)
│   └── Month (grid + day detail)
├── Focus
└── Settings
```

iPad/Mac sidebar: Today, Calendar, Search, Focus, Settings.

`DECISION` (Phase J): further calendar UI prefers merging into Upcoming Week/Agenda — already the host tab.

### 5.2 Screens — P0

#### App shell
- [ ] Root scene + `ModelContainer` injection
- [x] TabView (iPhone) — Browse / Upcoming / Focus / Settings
- [ ] First-launch onboarding lite: create Inbox, optional sample data, notification permission prompt timing (`DECISION`: ask after first reminder set)
- [ ] Settings screen shell

#### Today
- [x] Sections: Overdue (if any), Schedule (today’s blocks), Tasks due today, Maybe “No due date” omitted
- [x] Hosted as Browse → Today pane (not a root tab)
- [x] Tap task → Task Detail
- [x] Tap schedule block → Block Detail / occurrence actions
- [ ] Complete checkbox
- [ ] Empty state copy
- [ ] Pull to refresh not required for local DB; refresh on appear OK

#### Upcoming
- [x] Group by day for next 7 / 14 / 30 (`DECISION`: default 7)
- [x] Show tasks with due dates + optional schedule blocks per day
- [x] Week pane embeds timetable (replaces Timetable root tab)
- [ ] Jump to date (P1)
- [ ] P1 calendar: **host for calendar UI** (Agenda + Week already; avoid a new root Calendar tab — see Phase J)

#### Lists / Browse
- [x] Lists + Tags under Browse → Lists
- [x] List of lists with counts
- [x] List detail = filtered task list
- [ ] Create/edit list sheet
- [ ] Inbox special-casing

#### Timetable
- [x] Week strip + day agenda (embedded in Upcoming → Week)
- [ ] Active schedule picker if multiple (P1; MVP single schedule OK)
- [ ] Weekly grid (hours × days) (`RISK` layout performance) — P1/polish; agenda-by-day is current default
- [ ] Create/edit/delete schedule blocks
- [ ] Exception: skip / reschedule occurrence
- [ ] Color from swatch set

#### Task list shared UI
- [ ] `TaskRow`: checkbox, title, due, priority, list/tag hints
- [ ] Swipe actions: complete, reschedule, delete
- [ ] Multi-select later (P1)

#### Task Detail / Editor
- [ ] Title, notes
- [ ] List picker
- [ ] Due date + due time toggles
- [ ] Priority picker
- [ ] Tags picker
- [ ] Subtasks editor
- [ ] Recurrence editor (MVP frequencies)
- [ ] Reminder offsets editor
- [ ] Delete task

#### Quick Add
- [ ] Fast title entry from Today / lists
- [ ] Optional due date chips (Today / Tomorrow / Next week)
- [ ] Assign to current list context
- [ ] P1: natural language parsing

#### Tags
- [ ] Tag list + tag detail filtered tasks
- [ ] Create tag

#### Search
- [ ] Search field + results list
- [ ] Recent searches optional

#### Settings (P0)
- [ ] Account / Sign in with Apple
- [ ] Sync status
- [ ] Focus durations
- [ ] Notifications
- [ ] Default list
- [ ] Notification permission status + deep link to system settings
- [ ] Week starts on (Sunday/Monday) (`DECISION`)
- [ ] Time format follow system
- [ ] Supabase sync status / troubleshoot blurb
- [ ] App version
- [ ] About
- [ ] Debug: reset local store (DEBUG only)

### 5.3 Screens — P1
- [ ] Calendar month/week/day (prefer Upcoming panes; no new root tab)
- [ ] Filters sheet
- [ ] Multiple timetables manager
- [ ] Drag-resize blocks
- [ ] Focus / Pomodoro timer flows (Phase M; habits deferred)
- [ ] Widget configuration
- [ ] Keyboard shortcut cheatsheet (Mac)

### 5.4 Screens — P2
- [ ] Kanban board
- [ ] Eisenhower matrix
- [ ] Attachments viewer
- [ ] Sharing UI
- [ ] Stats / analytics
- [ ] Watch glances

---

## 6. Phase-by-phase work map

Each phase has **exit criteria**. Do not call a phase done until exit criteria pass on a real device or simulator at minimum.

---

### Phase A — Project foundation
**Goal:** App runs on iPhone/iPad/Mac with empty shell, Notebook tokens, local cache + Supabase client stubbed.

#### Work
- [ ] A1. Create Xcode multiplatform project **Tickytacky**
- [ ] A2. Capabilities: Sign in with Apple; App Group ID reserved
- [ ] A3. Folder structure + `ThemeTokens` / Notebook palette
- [ ] A4. GRDB/SQLite bootstrap + migrations stub
- [ ] A5. First-launch Inbox seed (local)
- [ ] A6. Root navigation shell (tabs/sidebar adaptive stub)
- [ ] A7. Settings placeholder
- [ ] A8. Supabase client config (plist/xcconfig — no secrets in git)
- [ ] A9. CI optional: `xcodebuild` smoke on simulator

#### Exit criteria
- [ ] App launches on iPhone simulator and Mac with Notebook canvas color
- [ ] Inbox exists after fresh install
- [ ] No crash on empty state

---

### Phase B — Tasks CRUD (local)
**Goal:** Capture and complete tasks without sync/recurrence.

#### Work
- [ ] B1. `TaskItem`, `TaskList`, `Subtask` models
- [ ] B2. `TaskService` / `ListService`
- [ ] B3. Lists UI + list detail
- [ ] B4. Task detail editor
- [ ] B5. Quick add
- [ ] B6. Complete / uncomplete
- [ ] B7. Delete + undo optional
- [ ] B8. Today view (due today + overdue only; no schedule yet)
- [ ] B9. Upcoming by due date
- [ ] B10. Priority + notes + due date/time
- [ ] B11. Subtasks UI
- [ ] B12. Empty states

#### Exit criteria
- [ ] Can create lists and tasks, set due dates, complete them
- [ ] Today/Upcoming show correct tasks for sample data
- [ ] Data survives app relaunch

---

### Phase C — Tags, search, sorting
**Goal:** Browse and find tasks at personal scale.

#### Work
- [ ] C1. `Tag` model + relationships
- [ ] C2. Tag picker in task editor
- [ ] C3. Tags browse + filtered list
- [ ] C4. Search UI + service
- [ ] C5. Sort rules documented and applied consistently
- [ ] C6. Task counts on lists

#### Exit criteria
- [ ] Tag filter and search return expected tasks
- [ ] Works with 200+ sample tasks without obvious jank

---

### Phase D — Recurrence engine (`RISK`)
**Goal:** Recurring tasks behave predictably.

#### Work
- [ ] D1. Write recurrence policy decision into docs
- [ ] D2. `RecurrenceRule` model
- [ ] D3. Pure `RecurrenceEngine` with unit tests:
  - [ ] daily / every N days
  - [ ] weekly
  - [ ] monthly edge cases
  - [ ] yearly
  - [ ] DST fixtures
- [ ] D4. Recurrence editor UI (MVP frequencies)
- [ ] D5. On complete → advance next occurrence
- [ ] D6. Upcoming expansion includes recurring series (if policy requires)
- [ ] D7. Editing recurrence: “this task only” vs “series” — MVP can support series-only (`DECISION`)

#### Exit criteria
- [ ] Unit tests green for core matrix
- [ ] Manual: create weekly task, complete, verify next due
- [ ] Manual: timezone change / DST week smoke test

---

### Phase E — Timetable / scheduling (`P0` centerpiece)
**Goal:** Recurring weekly schedule usable as a real timetable.

#### Work
- [ ] E1. `Schedule`, `ScheduleBlock`, `ScheduleException` models
- [ ] E2. `OccurrenceGenerator` + unit tests
- [ ] E3. Create/edit schedule block UI
- [ ] E4. Weekly timetable view (start with agenda-by-day if grid is slow)
- [ ] E5. Week grid view iteration
- [ ] E6. Validation (end after start, overlap warning optional)
- [ ] E7. Skip occurrence
- [ ] E8. Reschedule single occurrence
- [ ] E9. Color + optional list link
- [ ] E10. Wire timetable tab into navigation
- [ ] E11. Performance pass with dense week (e.g. 40 blocks)

#### Exit criteria
- [ ] Can model a school/work week
- [ ] Exceptions alter only intended occurrences
- [ ] Week navigation works (prev/next week)

---

### Phase F — Combined Today + schedule awareness
**Goal:** One place to see “what’s happening / due today.”

#### Work
- [x] F1. `TodayAssembler` merges tasks + occurrences
- [x] F2. Today UI sections redesigned
- [x] F3. Tap occurrence actions (open block, skip today)
- [x] F4. Upcoming optionally shows schedule blocks
- [x] F5. Sorting + accessibility labels

#### Exit criteria
- [x] Today is trustworthy for a real personal weekday
- [x] Completing tasks doesn’t break schedule section

---

### Phase G — Notifications (`APPLE`, `RISK`)
**Goal:** Reminders fire for tasks and timetable blocks.

#### Work
- [x] G1. Permission request UX + Settings status
- [x] G2. Map task reminders → `UNNotificationRequest`
- [x] G3. Map block reminders → notifications
- [x] G4. Reschedule pipeline on create/update/delete/complete
- [x] G5. Pending notification budget strategy
- [x] G6. Deep link notification → task/occurrence
- [x] G7. Foreground presentation rules
- [ ] G8. Device test (simulator limited; use physical iPhone)

#### Exit criteria
- [ ] Reminder fires on device for a task due in ~2 minutes
- [x] Editing/deleting removes obsolete notifications
- [ ] Timetable block reminder fires

---

### Phase H — Supabase auth + sync (`RISK`, `BLOCKER` for multi-device MVP)
**Goal:** Same data on two Apple devices via Supabase.

#### Work
- [x] H1. Supabase schema: lists, tasks, tags, schedules, blocks, exceptions (soft-delete, updated_at) — cloud
- [x] H2. RLS policies per user_id — cloud
- [x] H3. Sign in with Apple → Supabase session — client (`AuthService` + Settings)
- [x] H4. SyncEngine: push/pull (+ realtime subscribe **deferred**)
- [x] H5. Conflict: last-write-wins per record
- [x] H6. Offline queue then sync on reconnect (dirty `synced_at` + foreground/network sync)
- [x] H7. Sync status / error messaging in Settings
- [ ] H8. Large dataset smoke (optional / manual)
- [x] H9. Document “account required” limitation (Settings footer + `apps/ios/README.md`)

#### Exit criteria
- [ ] Task created on iPhone appears on Mac/iPad
- [ ] Schedule block syncs
- [ ] Offline create then online sync works
- [x] No silent data loss in common LWW case (document behavior) — see `SyncMapping.md`

---

### Phase I — MVP hardening & release candidate
**Goal:** Dogfoodable MVP.

#### Work
- [x] I1. Bug bash checklist (below) — code/empty-state pass; see `apps/ios/MVP_HARDENING.md`
- [x] I2. Accessibility pass — rows/checkboxes/headers/day strip
- [x] I3. Dynamic Type / landscape iPhone sanity — ScaledMetric + semantic fonts
- [x] I4. iPad usable layout (even if not polished) — split selection + single detail stack
- [x] I5. Mac window min sizes + basic keyboard delete/enter
- [ ] I6. Privacy Nutrition labels prep — **manual** (checklist in MVP_HARDENING.md)
- [ ] I7. TestFlight build — **manual**
- [ ] I8. Personal dogfood for 7 days — **manual**
- [x] I9. Fix P0 bugs only; park P1 ideas — `apps/ios/BUGS.md`

#### Exit criteria (MVP done)
- [ ] Meets `SCOPE.md` MVP success criteria
- [ ] Stable enough for personal daily use for a week
- [ ] Sync + reminders trusted

---

### Phase J — P1 planning surfaces (after dogfood)
Ordered after Phase M + full dogfood. Do as a batch (order within batch flexible):

- [ ] J1. Theme picker (additional token packs; `ThemeTokens` already exists)
- [ ] J2. Month calendar with badges
- [ ] J3. Week/day calendar integrating tasks + timetable
  - **DECISION (open):** Prefer **merging calendar into the existing Upcoming tab** (e.g. list + week/month toggle, or calendar header above the next-N-days list) instead of a fifth top-level tab — avoid IA bloat; validate in dogfood before committing to a separate Calendar tab
- [ ] J4. Optional NL quick add
- [ ] J5. Eisenhower matrix
- [ ] J6. Richer recurrence (custom weekdays, end conditions) — if capacity
- [ ] J7. Filters (list/tag/priority/scheduled) — if capacity
- [ ] J8. Multiple timetables + active switching — later polish
- [ ] J9. Conflict highlighting / drag on iPad/Mac — later polish

#### Exit criteria
- [ ] Calendar + theme + NL + matrix feel like a daily-driver upgrade, not toys
- [ ] Calendar IA decided: Upcoming merge **or** separate tab — documented after dogfood

---

### Phase K — Widgets + App Intents (**consider after J**)
Do **not** start until the J batch has been dogfooded. Revisit whether widgets are worth it.

- [ ] K1. Shared App Group store access for widgets
- [ ] K2. Home Screen widget: Today tasks
- [ ] K3. Widget: next timetable block
- [ ] K4. Configurable widgets
- [ ] K5. App Intents: Add Task, Complete Task, What’s Next
- [ ] K6. Shortcuts app verification
- [ ] K7. Lock Screen widgets if feasible

#### Exit criteria
- [ ] Widget updates after task changes (timeline reload strategy working) — *if* K is undertaken

---

### Phase L — P1 platform polish
- [ ] L1. iPad sidebar navigation + inspector
- [ ] L2. Multiwindow (Mac/iPad) if worthwhile
- [ ] L3. Mac menu bar commands
- [ ] L4. Full keyboard shortcut set
- [ ] L5. Handoff activity for selected task (optional)
- [ ] L6. Performance profiling on large data

---

### Phase M — Focus / Pomodoro (**next after MVP code**)
**Chosen:** Focus / Pomodoro (D10 locked). Habits deferred to N.

- [x] M-F1. Focus session model
- [x] M-F2. Timer UI (Notebook vibe)
- [x] M-F3. Link session to task
- [x] M-F4. Session-end notification
- [ ] M-F5. Live Activity optional stretch

#### Exit criteria
- [ ] Pomodoro usable in daily planning; then start **full dogfood**

#### After M — Full dogfood gate
- [ ] Real-week use as primary planner
- [ ] Finish remaining MVP manual checks (Sign in with Apple, two-device sync, G8 device fire, TestFlight if desired)
- [ ] Only then start Phase J

---

### Phase N — P2 expansion (only after daily driver / J batch)
- [ ] Habits (if still wanted)
- [ ] Kanban
- [ ] Attachments
- [ ] Collaboration architecture spike (Supabase already supports; design sharing later)
- [ ] EventKit sync spike (`RISK` — often more pain than value)
- [ ] Apple Watch app
- [ ] Advanced analytics
- [ ] Widgets if skipped in K

---

## 7. Cross-cutting concerns checklist

### 7.1 Time & calendars (`RISK` everywhere)
- [ ] Pick app `Calendar` identity (user current, with timezone updates on foreground)
- [ ] Define date-only vs datetime storage
- [ ] Define “start of week”
- [ ] All generators take explicit `Calendar` + `TimeZone` in tests
- [ ] Travel across timezones: document expected behavior for timetable (usually anchored to local TZ)

### 7.2 Performance budgets
- [ ] Today loads < 100ms for 500 tasks locally on modern iPhone (aspirational; measure)
- [ ] Timetable week render smooth on scrolling
- [ ] Avoid N+1 query patterns in GRDB list fetches
- [ ] Use `@Query` predicates narrowly

### 7.3 Accessibility
- [ ] Every checkbox has accessible label including task title
- [ ] Timetable blocks VoiceOver-navigable
- [ ] Color never sole priority indicator
- [ ] Reduce Motion: disable nonessential animations

### 7.4 Privacy & security
- [ ] Data lives in user’s Supabase account (RLS)
- [ ] No analytics SDK in MVP unless explicitly wanted
- [ ] Privacy policy if App Store public
- [ ] No logging of task titles to third parties

### 7.5 Error handling
- [ ] User-visible errors for sync failure
- [ ] Notification permission denied state
- [ ] Corruption recovery plan (export later; at least don’t crash-loop)

---

## 8. Testing map

### 8.1 Unit tests (required early)
- [ ] RecurrenceEngine matrix
- [ ] OccurrenceGenerator + exceptions
- [x] TodayAssembler sorting/sectioning
- [x] ReminderScheduler request building (identifiers stable/idempotent)

### 8.2 UI / integration
- [ ] Smoke UI tests: create task, complete task (optional P0, stronger P1)
- [ ] Snapshot tests optional

### 8.3 Manual device matrix
| Device | P0 must test |
|--------|----------------|
| iPhone | Primary UX, notifications |
| iPad | Navigation doesn’t break |
| Mac | Windowing + keyboard basics |
| 2 devices + Supabase | Sync |

### 8.4 Dogfood protocol
- [ ] Import a week of real tasks/timetable
- [ ] Use as daily driver for 7 days before calling MVP “done”
- [ ] Keep a running bug list (`BUGS.md` optional)

---

## 9. App Store / distribution map (when ready)

- [ ] App name, subtitle, keywords
- [ ] Screenshots (iPhone, iPad, Mac if Mac App Store)
- [ ] Privacy Nutrition Labels (account / sync)
- [ ] Encryption export compliance
- [ ] TestFlight internal → external
- [ ] App Review notes (Sign in with Apple + account sync)
- [ ] Support URL / marketing site optional
- [ ] Versioning scheme (SemVer or marketing + build)

---

## 10. Dependency graph (what blocks what)

```text
A Foundation (Tickytacky + Notebook + GRDB + Supabase stub)
 └── B Tasks CRUD
      ├── C Tags/Search
      ├── D Recurrence ──────────────┐
      └── E Timetable ───────────────┤
           └── F Combined Today <────┘
                ├── G Notifications
                └── H Supabase Auth + Sync
                     └── I MVP Hardening  → MVP SHIP (code)
                          └── M Pomodoro / Focus
                               └── Full dogfood gate
                                    └── J Theme + Calendar + NL + Eisenhower
                                         ├── K Widgets (consider)
                                         ├── L Platform polish
                                         └── N P2 (habits, Kanban, …)
```

**Critical path to MVP:** A → B → (D and E in parallel after B) → F → G → H → I

**Post-MVP (locked 2026-08-25):** M → dogfood → J → (consider K) → L/N as needed

---

## 11. Order & priority roadmap

This section sequences work by **order** (what comes before what) and **priority** (what matters most). It intentionally has **no days, weeks, hours, or calendar targets**.

### 11.1 Priority levels

| Priority | Meaning | Rule |
|----------|---------|------|
| **P0** | MVP — required to dogfood as a daily personal planner | Do in order below; do not skip ahead to P1 |
| **P1** | Daily-driver upgrades | Only after MVP exit criteria pass |
| **P2** | TickTick-like extras | Only after daily-driver success |
| **Parked** | Nice ideas not in scope yet | Do not start |

Within a priority band, follow **sequence order** (lower number first). Items with the same sequence may run in parallel if dependencies allow.

### 11.2 Master sequence (do in this order)

| Seq | ID | Work | Priority | Depends on | Parallel OK with |
|-----|----|------|----------|------------|------------------|
| 0 | **Dec** | Lock decisions D1–D9 | P0 | — | — |
| 1 | **A** | Foundation (Xcode, shell, GRDB, Supabase stub) | P0 | Dec | — |
| 2 | **B** | Tasks CRUD + Today/Upcoming (local) | P0 | A | — |
| 3 | **C** | Tags + search | P0 | B (or late B) | Early D/E only after B core works |
| 4a | **D** | Recurrence engine + UI | P0 | B | **E** |
| 4b | **E** | Timetable / schedule blocks + week view | P0 | B | **D** |
| 5 | **F** | Combined Today (tasks + timetable slots) | P0 | D + E | — |
| 6a | **G** | Notifications | P0 | F | **H** (after F) |
| 6b | **H** | Supabase auth + sync | P0 | F | **G** |
| 7 | **I** | MVP hardening + dogfood prep | P0 | G + H | — |
| — | **MVP SHIP** | Gate: code ready; manual checks fold into post-M dogfood | P0 | I | — |
| 8 | **M** | **Pomodoro / Focus** | P1 | MVP SHIP | — |
| — | **Full dogfood** | Real-week use + remaining MVP manual checks | P1 | M | — |
| 9 | **J** | Theme picker + calendar + NL quick-add + Eisenhower | P1 | Full dogfood | — |
| 10 | **K** | Widgets + App Intents (**consider**) | P1 | J dogfooded | Optional |
| 11 | **L** | iPad / Mac polish | P1 | After J (flexible) | — |
| — | **Daily driver** | Gate: prefer this app over TickTick/Reminders | P1 | M + dogfood + J | — |
| 12+ | **N** | Habits, Kanban, Watch, collab, EventKit, etc. | P2 | Daily driver | Among themselves as desired |

**Critical path (strict order):**  
`Dec → A → B → (D ∥ E) → F → (G ∥ H) → I → MVP SHIP → M → dogfood → J → (consider K) → Daily driver → N`

### 11.3 Milestone order (priority gates, not dates)

| Order | Milestone | Priority | Done when |
|-------|-----------|----------|-----------|
| M0 | Decisions locked | P0 | Section 0 checkboxes done |
| M1 | Foundation runnable | P0 | Phase A exit criteria |
| M2 | Local task app usable | P0 | Phase B exit criteria |
| M3 | Findable tasks | P0 | Phase C exit criteria |
| M4 | Recurrence trustworthy | P0 | Phase D exit criteria |
| M5 | Real weekly timetable encodable | P0 | Phase E exit criteria |
| M6 | Today shows tasks + slots | P0 | Phase F exit criteria |
| M7 | Reminders trusted on device | P0 | Phase G exit criteria |
| M8 | Two devices sync | P0 | Phase H exit criteria (may complete during dogfood) |
| **M9** | **MVP SHIP (code)** | **P0** | Phase I code complete |
| M10 | Pomodoro in daily use | P1 | Phase M exit criteria |
| **M11** | **Full dogfood** | **P1** | Real-week use + remaining manual MVP checks |
| M12 | Theme + calendar + NL + Eisenhower | P1 | Phase J exit criteria |
| M13 | Widgets useful (optional) | P1 | Phase K if undertaken |
| M14 | iPad/Mac feel native | P1 | Phase L exit criteria |
| **M15** | **Daily driver** | **P1** | P1 success criteria in `SCOPE.md` |
| M16+ | Expansion | P2 | Phase N items individually |

### 11.4 What may run in parallel

| Parallel set | Condition | Still blocked until |
|--------------|-----------|---------------------|
| D ∥ E | Phase B core CRUD works | Do not start either before B |
| G ∥ H | Phase F combined Today works | Do not enable multi-device sync until models stable from F |
| Items inside J | After full dogfood | Theme / calendar / NL / matrix can interleave |
| L with late J | J core done | Shared UX must stay coherent |
| P2 items | Daily driver achieved | Never parallel with unfinished P0 |

### 11.5 What must never jump the queue

| Temptation | Priority | Do this instead |
|------------|----------|-----------------|
| Widgets before Pomodoro + dogfood + J | P1 before locked order | Finish M → dogfood → J first; then *consider* K |
| Habits before Pomodoro | Locked Focus first | Habits only in N if still wanted |
| Calendar/NL/Eisenhower before dogfood | P1 before dogfood | Ship M, dogfood, then J |
| Kanban early | P2 | Park in N |
| Full Supabase sync on day one | P0 but late sequence | Local B–F first, then H |
| Mac polish before iPhone Today works | P1 before P0 | Sequence L after MVP |
| Theme picker before MVP | P1 | Notebook only until M9; theme in J |
| Android/web before Apple MVP | P2 | Same API later |

### 11.6 Relative weight (not time)

Use only to decide **attention**, not schedules. Higher weight ⇒ expect more care, tests, and rework — not “longer on the calendar.”

| Weight | Meaning |
|--------|---------|
| **W1** | Straightforward wiring / UI |
| **W2** | Multi-screen feature; normal complexity |
| **W3** | High risk / subtle correctness (timezones, sync, notifications, generators) |

| Seq | Phase | Priority | Weight |
|-----|-------|----------|--------|
| Dec | Decisions | P0 | W1 |
| A | Foundation | P0 | W2 |
| B | Tasks CRUD | P0 | W2 |
| C | Tags/Search | P0 | W1 |
| D | Recurrence | P0 | W3 |
| E | Timetable | P0 | W3 |
| F | Combined Today | P0 | W2 |
| G | Notifications | P0 | W3 |
| H | Supabase sync | P0 | W3 |
| I | Hardening | P0 | W2 |
| J | Theme/Calendar/NL/Eisenhower | P1 | W2–W3 |
| K | Widgets/Intents (optional) | P1 | W2 |
| L | Platform polish | P1 | W2 |
| M | Pomodoro / Focus | P1 | W2 |
| N | P2 bag | P2 | W3 (varies) |

### 11.7 Checkpoint reviews (by sequence, not calendar)

| After | Review question | If fail |
|-------|-----------------|---------|
| B | Would I enter real tasks here? | Fix UX before starting D/E |
| E | Can I encode my real weekly timetable? | Simplify to day-agenda before fancy grid |
| H | Do two devices stay consistent through normal use? | Do not call MVP done; stay on H |
| I | Still reaching for TickTick for basics? | Log top blockers; fix before calling code-shipped |
| M | Is Pomodoro actually used? | Fix timer UX before full dogfood / J |
| Dogfood | Prefer Tickytacky for a real week? | Stay fixing; do not start J |
| J | Daily-driver upgrade landed? | Stay on J; do not start K/N |

### 11.8 Scope-creep risks (priority discipline)

| Risk | Why it hurts order | Mitigation |
|------|--------------------|------------|
| Recurrence edge-case rabbit holes | Stalls seq 4a forever | Limit MVP rule set; park fancy rules in J |
| Perfect timetable grid before agenda works | Stalls seq 4b | Agenda first, grid second (still inside E) |
| Notification perfectionism | Stalls seq 6a | Soonest-N reminders only for MVP |
| Schema churn during sync | Forces H rework | Freeze models before H; no new entities mid-sync |
| “Quick” P1 features during P0 | Breaks critical path | Park list; protect M9 |
| Building N items because they’re fun | Never reaches daily driver | Hard gate: M14 before N |
| Premature Android/web | Splits focus | Apple MVP first; same Supabase API later |

### 11.9 Status log (order only)

Track position on the sequence — not dates:

| Current seq | Milestone | Status (`todo` / `active` / `done`) | Notes |
|-------------|-----------|-------------------------------------|-------|
| 0 | M0 Decisions | done | Tickytacky + Supabase + defaults |
| 1 | M1 Foundation | done | Local: apps/ios XcodeGen + GRDB + shell |
| 2 | M2 Tasks CRUD | done | Local Phase B |
| 3 | M3 Tags/Search | done | Local Phase C |
| 4 | M4+M5 Recurrence∥Timetable | done | Local D + E |
| 5 | M6 Combined Today | done | Local Phase F |
| 6 | M7+M8 Reminders∥Sync | active | G done locally; H client done (realtime deferred); remote needs `…00005` + Secrets dogfood |
| 7 | M9 MVP SHIP | active | Phase I code (I1–I5, I9) done; I6–I8 manual |
| 10 | M14 Daily driver | todo | |

**Now working on:** `seq 7` / phase `I` code hardening done; manual I6–I8 + two-device sync + G8 device fire + apply `20260819000005_lww_updated_at.sql` on remote

---

## 12. Definition of done (per feature)

A feature is done only when:
1. Data model supports it
2. Domain logic covered by tests where math/time involved
3. UI exists on iPhone at minimum
4. Works offline
5. Survives relaunch
6. Sync impact considered (Supabase schema + RLS)
7. Notifications updated if time-related
8. Accessibility basics checked
9. Checkbox marked in this map **and** `SCOPE.md` if it maps to a scoped item

---

## 13. Immediate next actions (start here)

1. [x] Confirm decisions D1–D9 / defaults (`MEM.md`)
2. [ ] Set **Now working on** in [§11.9](#119-status-log-order-only) to `seq 1 / A`
3. [ ] Create Xcode multiplatform project **Tickytacky** (Phase A)
4. [ ] Implement GRDB models for List + Task (start Phase B)
5. [ ] Build Today + List UI against local cache (Notebook theme)
6. [ ] Do **not** start full Supabase sync, widgets, or P1 features until sequence says so (after F / then H)

---

## 14. Living document rules

- Update checkboxes as work completes
- When a `DECISION` is resolved, replace the line with the chosen option
- When a phase finishes, update [§11.9 status log](#119-status-log-order-only) (`todo` → `done`) and move **Now working on**
- If scope changes, update `SCOPE.md` first, then mirror sequence/priority here
- Do **not** add calendar/hour estimates back into §11
- Park out-of-scope ideas under Phase N — do not smuggle into P0
