# MVP Hardening (Phase I)

Automated / code hardening for Tickytacky MVP. This file tracks what was done in-repo vs what you still run by hand.

## Done in code (I1–I5, I9)

- Light bug-bash: missing-task / missing-list / missing-tag empty states; Timetable add-sheet when schedule fails; Sync/Settings safe when Secrets unset
- Accessibility: task rows, checkboxes, schedule rows, timetable day strip, Browse/Settings section headers
- Dynamic Type: ScaledMetric on checkbox / FAB / priority dots; semantic fonts on schedule time labels
- iPad/Mac: `NavigationSplitView` sidebar selection + single detail `NavigationStack` (no nested stacks)
- Mac: default 1100×720, min 720×480; ⌫ deletes selected tasks on task lists (Return activates focused row/link)
- P0-only fixes; P1 ideas parked in [`BUGS.md`](BUGS.md)

## Manual checklist (you)

Do **not** expect Cloud Agents to complete these.

### Release / App Store Connect

- [ ] Archive a release build in Xcode
- [ ] Upload to **TestFlight** (App Store Connect)
- [ ] Fill **Privacy Nutrition Labels** (Account, Sync, Notifications as applicable)
- [ ] Personal dogfood for ~7 days on a daily-driver device

### Reminders (G8)

- [ ] On a **physical iPhone**, enable a task due-time reminder and a timetable block reminder; confirm they **fire** (Simulator scheduling ≠ reliable fire)

### Sync / Secrets

- [ ] Copy `Secrets.example.xcconfig` → `Secrets.xcconfig` with real `SUPABASE_URL` + `SUPABASE_ANON_KEY`
- [ ] Enable **Sign in with Apple** provider in the Supabase project
- [ ] Two-device smoke: sign in on two Apple devices, edit on A, Sync Now / foreground on B, confirm LWW

### Supabase migration (remote)

Apply on any remote DB that does not yet have it (Cloud workflow unchanged beyond this note):

- `supabase/migrations/20260819000005_lww_updated_at.sql` — preserves client `updated_at` for LWW

```bash
# from repo root, against your linked remote project
supabase db push
# or apply the SQL file in the Supabase SQL editor
```

### Parked (not in Phase I)

- Realtime subscribe (foreground + Sync Now only)
- Privacy form filing beyond prep notes above
- P1 polish listed in `BUGS.md`

## Ship-readiness notes (2026-08-19 pass)

Fixed before dogfood:

- UUID case mismatch on sync (lowercase `RecordID` + `v8_normalize_ids`)
- Dual-Inbox reconcile + account-switch wipe
- Dirty-local LWW (no clobber mid-edit); safe `synced_at` bump
- Cross-week timetable reschedule visibility
- Recurrence date-only encoding uses local calendar
- Removed unused App Group entitlement (less signing friction)
- Corrupt-cache one-shot recovery on launch
- Debounced recurring-task double-complete

Still required before calling MVP **shipped**: Secrets, Apple provider, remote `…00005`, two-device smoke, G8 physical fire, TestFlight + dogfood.
