# Tickytacky

Personal planner — Apple-first, Supabase-backed, Classic Notebook design.

| Doc | Purpose |
|-----|---------|
| [MEM.md](MEM.md) | Living decisions / status |
| [SCOPE.md](SCOPE.md) | Product scope |
| [IMPLEMENTATION_MAP.md](IMPLEMENTATION_MAP.md) | Build sequence |
| [DESIGN.md](DESIGN.md) | Design language |

## Stack

- **Clients:** SwiftUI (iPhone / iPad / Mac first; Android & web later)
- **API:** Supabase (Postgres + Auth + Realtime)
- **Local cache:** GRDB / SQLite

## Build environments

Work in this repo splits across two build environments. See
[IMPLEMENTATION_MAP.md §Build environments](IMPLEMENTATION_MAP.md#build-environments-cloud-vs-local)
for the per-phase breakdown.

| Environment | Builds | Where |
|-------------|--------|-------|
| **Cloud** (Linux Cloud Agent) | Supabase backend — `supabase/` schema migrations, RLS, auth config, seed, Edge Functions. Runnable + testable against the local Supabase stack (`.cursor/` sets this up). | `supabase/` |
| **Local** (macOS + Xcode) | SwiftUI clients — the entire app (Apple frameworks cannot build on Linux). | `apps/ios/` |

## Status

Phase A foundation — see MEM.md.
