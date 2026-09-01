# Calendar bridge — implementer ready checklist

Phases 1–4 are implemented in-app. Use this for dogfood / shipping gates.

## Apple (Phase 1 + 2)

- [x] One-way publish / disable clear / Publish now
- [x] Full calendar access for two-way observation
- [x] Echo suppression around EventKit commit
- [x] Conflict rules in `CalendarConflictResolver` + `CalendarBridge.md`
- [x] `AppleCalendarBridge` wraps `EventKitCalendarPublisher`
- [ ] Confirm dogfood: enable/disable, permission denied, Calendar.app edit → Tickytacky

## Google (Phase 3 + 4)

- [ ] Google Cloud Console project for Tickytacky
- [ ] OAuth 2.0 Client ID (iOS) — set `GOOGLE_CALENDAR_CLIENT_ID` + `GOOGLE_CALENDAR_REVERSED_CLIENT_ID` in `Secrets.xcconfig`
- [ ] Enable **Google Calendar API**
- [x] Scope: `https://www.googleapis.com/auth/calendar` (documented in `CalendarBridge.md`)
- [x] ASWebAuthenticationSession + PKCE (no GoogleSignIn SPM)
- [x] Dedicated Google calendar titled **Tickytacky**; persist calendar id + sync token
- [x] Two-way pull via sync token + same conflict rules
- [ ] App Store / privacy nutrition labels for calendar data when shipping
- [ ] Dogfood Google-only publish; confirm no duplicate if Apple off

## Permissions & privacy copy

- [x] Apple usage strings in project.yml (full access copy mentions two-way)
- [x] Settings footers warn about dual-write duplicates
- [ ] Google privacy labels at App Store submission

## Dogfood steps (any phase that writes)

1. Fresh install or clear Tickytacky calendar events
2. Create a few timetable blocks; enable bridge; open Calendar.app / Google Calendar
3. Edit in Tickytacky; confirm external update
4. Toggle off; confirm cleanup
5. (Two-way only) Edit externally; confirm Tickytacky behaviour matches conflict rules

## Out of scope until product says otherwise

- Reminders / Google Tasks
- Task due dates as events
- GRDB migration for mapping (UserDefaults OK)
- Multi-provider conflict UI
