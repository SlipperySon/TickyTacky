# Tickytacky (Apple)

> **Build environment: Local only (macOS + Xcode).** Cannot build on a Linux Cloud Agent.
> Backend: [`../../supabase/`](../../supabase/). See IMPLEMENTATION_MAP §Build environments.

SwiftUI multiplatform app (`app.tickytacky.ios`).

```bash
cd apps/ios
xcodegen generate   # after adding/removing sources
open Tickytacky.xcodeproj
# or:
xcodebuild -project Tickytacky.xcodeproj -scheme Tickytacky \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

- Local cache: GRDB/SQLite
- Theme: Classic Notebook (`ThemeTokens` / `NotebookTokens`)
- Secrets: copy `Secrets.example.xcconfig` → gitignored `Secrets.xcconfig`
- **Reminders (Phase G):** Local notifications via `ReminderScheduler`. Permission is requested when the user first enables a reminder (also controllable in Settings). **True timed delivery should be verified on a physical iPhone** — Simulator can schedule pending requests, but fire behavior is limited/flaky.
- **Auth + sync (Phase H client):** Sign in with Apple via Supabase Auth (`AuthService`). `SyncEngine` pull/push with LWW on `updated_at`. **Account required for multi-device sync**; offline local CRUD works without signing in. Field mapping: `Tickytacky/Data/Sync/SyncMapping.md`. Realtime subscribe deferred (foreground + Sync Now).
- **MVP hardening (Phase I):** See [`MVP_HARDENING.md`](MVP_HARDENING.md) for code vs manual checklist (TestFlight, Privacy labels, G8 device fire, two-device sync, migration `…00005`). P1 ideas: [`BUGS.md`](BUGS.md).
