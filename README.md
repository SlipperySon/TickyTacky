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

| Environment | Builds |
|-------------|--------|
| **Cloud** (Linux) | `supabase/` backend |
| **Local** (macOS + Xcode) | `apps/ios/` SwiftUI client |

## Status

Local: Phase A+B done; Phase C next. Cloud: Phase H schema. See MEM.md.
