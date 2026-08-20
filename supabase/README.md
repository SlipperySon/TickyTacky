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

## Schema

Migrations live in `migrations/` and define the P0 domain (see
[IMPLEMENTATION_MAP.md §3](../IMPLEMENTATION_MAP.md)):

- `lists`, `tasks`, `subtasks`, `tags`, `task_tags`
- `schedules`, `schedule_blocks`, `schedule_exceptions` (first-class timetable)

Conventions applied to every synced table:

- `user_id → auth.users(id)` ownership, enforced by **RLS** (an authenticated
  user only sees/writes their own rows; `service_role` bypasses; `anon` has no access).
- `updated_at` (auto-maintained by trigger) for last-write-wins sync.
  Migration `20260819000005_lww_updated_at.sql` preserves client-supplied
  `updated_at` when it changes (required for SyncEngine LWW).
- `deleted_at` for soft-delete.
- **Compact storage** (`20260819000006_storage_compact.sql`): dropped unused
  columns (`lists.icon`, `recurrence_end` / `by_weekdays`, `schedule_blocks.tag_id`),
  nullable recurrence fields (no default interval on every task), `smallint`
  sort/reminder fields, text length caps, empty-string → NULL, tighter indexes,
  and `purge_soft_deleted(interval)` to hard-delete old tombstones.

Apply migrations + seed to a fresh local DB:

```bash
supabase db reset
```

### Storage / purge

Soft-deleted rows still consume space until purged:

```sql
select * from public.purge_soft_deleted(interval '30 days');
```

Grant is `service_role` only. Schedule monthly via Supabase cron or run after
dogfood. Occurrences are never stored (computed client-side) — only exceptions.

`seed.sql` creates a demo user and sample data for local development:

- **Demo login (local only):** `demo@tickytacky.app` / `tickytacky`

## Linking a hosted project

```bash
supabase login
supabase link --project-ref <ref>
```
