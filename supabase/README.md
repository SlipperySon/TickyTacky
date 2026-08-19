# Tickytacky Supabase

Canonical backend for Tickytacky.

> **Build environment: Cloud-buildable (Linux Cloud Agent).** Schema migrations,
> RLS, auth config, seed, and Edge Functions here can be built and tested against
> the local Supabase stack — no Mac required. The SwiftUI client in
> [`../apps/ios/`](../apps/ios/) is local-only (macOS + Xcode).
> See [IMPLEMENTATION_MAP.md §Build environments](../IMPLEMENTATION_MAP.md#build-environments-cloud-vs-local).

## Local development

A local Postgres + Auth + Realtime + Storage + Studio stack runs via the
Supabase CLI (Docker). In a Cloud Agent this is started automatically by
`.cursor/start.sh`; to run it yourself:

```bash
supabase start     # boots the local stack (Docker required)
supabase status    # prints local URLs + keys
supabase stop      # tears it down
```

Local endpoints (see `config.toml` for ports):

| Service | URL |
|---------|-----|
| API gateway (Kong) | http://127.0.0.1:54321 |
| Postgres | postgresql://postgres:postgres@127.0.0.1:54322/postgres |
| Studio | http://127.0.0.1:54323 |
| Mailpit (email testing) | http://127.0.0.1:54324 |

## Linking a hosted project

```bash
supabase login
supabase link --project-ref <ref>
```

Migrations live in `migrations/`.
