# Tickytacky

Personal planner — Apple-first, Supabase-backed, Classic Notebook design.

| Doc | Purpose |
|-----|---------|
| [MEM.md](MEM.md) | Living decisions / status |
| [SCOPE.md](SCOPE.md) | Product scope |
| [IMPLEMENTATION_MAP.md](IMPLEMENTATION_MAP.md) | Build sequence |
| [DESIGN.md](DESIGN.md) | Design language |

## Stack

- **Clients:** SwiftUI Apple app first; separate Web / Android / Windows prototypes in `apps/`
- **API:** Supabase (Postgres + Auth + Realtime)
- **Local cache:** GRDB / SQLite (Apple)

## Apps

| Path | What it is |
|------|------------|
| [`apps/ios/`](apps/ios/) | **Tickytacky** — iPhone, iPad, Mac (shipping client) |
| [`apps/web/`](apps/web/) | **Tickytacky Web** — browser prototype |
| [`apps/android/`](apps/android/) | **Tickytacky Android** — native Android prototype |
| [`apps/windows/`](apps/windows/) | **Tickytacky Windows** — WPF prototype |

See [`apps/README.md`](apps/README.md). Do not mix these trees; shared data later via Supabase.

## Build environments

| Environment | Builds |
|-------------|--------|
| **Cloud** (Linux) | `supabase/` backend; `apps/web/` |
| **Local** (macOS + Xcode) | `apps/ios/` SwiftUI client |
| **Local** (Android Studio) | `apps/android/` |
| **Local** (Windows + .NET 8) | `apps/windows/` |

## Status

Local: Phase A+B done; Phase C next. Cloud: Phase H schema. See MEM.md.
