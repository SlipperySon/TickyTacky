# Calendar bridge — ready-to-build / implemented spec

**Product intent:** Tickytacky is another calendar in the Apple Calendar + Google mixer. Users see a dedicated **Tickytacky** calendar alongside iCloud/Google. Tickytacky remains source of truth for now. Prefer **timetable occurrences** first. Avoid dual-write duplicates (never publish the same occurrence to both Apple and Google when Calendar.app already mirrors Google).

**Implementation:**
- Apple publish/pull: `Data/Services/EventKitCalendarPublisher.swift`
- Google publish/pull: `Domain/CalendarBridge/GoogleCalendarPublisher.swift` (+ OAuth/API)
- Shared: `CalendarOccurrenceLoader`, `CalendarExternalIDStore`, `CalendarConflictResolver`, `CalendarBridgeCoordinator`
- Thin `CalendarBridgeProvider` wrappers: `AppleCalendarBridge`, `GoogleCalendarBridge`
- Checklist: [`READY_CHECKLIST.md`](./READY_CHECKLIST.md)

---

## Shared rules (all phases)

### What we sync
- **In scope:** weekly **timetable** `ScheduleOccurrence`s (materialised horizon, currently ~8 weeks).
- **Out of scope for v1 bridge:** task due dates as events, Reminders/Tasks lists, Focus sessions, arbitrary “everything in Tickytacky.”

### Identity & matching
- Stable Tickytacky id = occurrence id (`blockID|ISO8601`).
- Apple tag: `tickytacky://schedule?id=<occurrenceId>` on `EKEvent.url`.
- Google: `extendedProperties.private.tickytackyOccurrenceId` (+ deep link in description for recovery).
- Mapping rows in UserDefaults via `CalendarExternalIDStore` (`lastPublishedAt` for conflict / echo).
- Never create a second Tickytacky calendar by title alone without checking cached calendar id.

### Duplicate avoidance
- **One provider at a time for write** when the user already has Google → Apple Calendar mirroring.
- Settings: independent Apple / Google toggles + dual-write warning when both are on.
- Within a provider: upsert by occurrence id; delete orphans outside the keep set; collapse duplicate tags on publish.

### Conflict rules (two-way)
When Tickytacky is still **source of truth**:
1. **Tickytacky edit** → overwrite external event (title, start, end, notes).
2. **External edit** (title/time only) → apply only if fields differ **and** external change is after `lastPublishedAt` (see `CalendarConflictResolver`); otherwise keep Tickytacky and re-publish.
3. **External delete** → do **not** delete the timetable block; re-create the event on next publish.
4. **Structural Tickytacky change** (weekday/rule/exception) → occurrence ids may change; treat as delete old + create new; never invent exceptions from Calendar.app recurrence edits in v1.
5. **Simultaneous edit** → Tickytacky wins; next publish overwrites external.

Echo suppression: publishers set a short `ignoringExternalChangesUntil` window around commit/API writes.

### Non-goals (until explicitly revisited)
- Apple Reminders / Google Tasks
- Full two-way multi-provider conflict UI
- Pushing every task due date as a calendar event
- Google Sign-In SPM (uses ASWebAuthenticationSession + REST instead)
- GRDB migrations for mapping (UserDefaults JSON is enough for now)

---

## Phase 1 — Apple one-way ✅

| Item | Status |
|------|--------|
| Dedicated EventKit calendar titled **Tickytacky** | Done |
| Publish timetable occurrences (~8 week horizon) | Done |
| Settings toggle; off clears published events | Done |
| Match via `tickytacky://schedule?id=` | Done |
| Tickytacky = source of truth; Calendar.app = projection | Done |
| Cached calendar identifier + mapping `lastPublishedAt` | Done |

---

## Phase 2 — Apple two-way / pull ✅

| Item | Status |
|------|--------|
| Full calendar access required for pull | Done |
| `EKEventStore.changed` + debounce + echo window | Done |
| Conflict resolver + `rescheduleOccurrence` / title `updateBlock` | Done |
| Settings: “Allow Calendar edits to update Tickytacky” | Done |
| External delete → re-publish (no local delete) | Done |

---

## Phase 3 — Google one-way ✅

| Item | Status |
|------|--------|
| PKCE OAuth via ASWebAuthenticationSession (no GoogleSignIn SPM) | Done |
| Secrets / Info.plist: `GOOGLE_CALENDAR_CLIENT_ID` + reversed URL scheme | Done |
| Dedicated Google calendar **Tickytacky**; upsert + clear on disable | Done |
| Settings toggle + Sign in with Google; graceful if client id missing | Done |
| Dual-write warning when Apple + Google both enabled | Done |

**Scope:** `https://www.googleapis.com/auth/calendar`

---

## Phase 4 — Google two-way ✅

| Item | Status |
|------|--------|
| Incremental list via sync token | Done |
| Same conflict rules as Apple pull | Done |
| Settings two-way toggle under Google | Done |

---

## Test plan

### Automated
- [x] Occurrence ↔ deep-link round trip (`ScheduleOccurrence` calendar bridge URL / parseID)
- [x] Conflict resolver table (Tickytacky wins / external title apply / ignore)
- [ ] Duplicate collapse when two events share the same occurrence id (manual / publish path)
- [ ] Horizon window: events outside keep set removed (manual)

### Manual dogfood
- [ ] Enable Apple → events appear in Calendar.app under Tickytacky
- [ ] Edit block in Tickytacky → external updates
- [ ] Disable → events cleared
- [ ] Deny permission → Settings explains; no crash
- [ ] (Phase 2) Edit time in Calendar.app → Tickytacky updates per rules
- [ ] (Phase 3) Google-only publish; confirm no duplicate if Apple off
- [ ] Never enable both writes while Google is subscribed in Calendar.app without understanding duplicate risk

---

## Risk

Full two-way multi-provider sync is easy to get wrong (dupes, exception mapping, echo loops). Features stay behind Settings; conflict rules + echo suppression are required for pull.
