# Bugs & follow-ups

P0 items from Phase I were fixed in code. Park P1+ here so they don’t block MVP dogfood.

## P1 (parked)

- Timetable **grid** day/week layout (agenda strip is MVP)
- Richer empty states with inline CTAs (e.g. “Add block” from Timetable empty)
- VoiceOver rotor / custom actions beyond “Toggle completion” on task rows
- iPad multitasking / Stage Manager edge cases for nested sheets
- Large Dynamic Type: timetable week strip may need horizontal scroll at accessibility sizes
- Search: highlight match spans in results
- Mac: explicit Return → open selected task via `NavigationPath` (List + NavigationLink usually handles focus/Return)

## P2 / later

- Realtime sync subscribe (deferred from Phase H)
- Conflict UI when LWW overwrites local edits
- Export / corruption recovery UX

## Fixed in Phase I (reference)

- Task detail hung on spinner when task missing → `ContentUnavailableView`
- List/tag detail empty hole when record deleted
- Nested `NavigationStack` on regular size → split detail owns one stack
- Hardcoded checkbox / FAB point sizes → `ScaledMetric` + semantic fonts
