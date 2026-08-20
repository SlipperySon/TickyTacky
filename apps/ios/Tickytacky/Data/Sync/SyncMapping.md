# Local ↔ Supabase field mapping (Phase H)

Source of truth for remote shapes: `supabase/migrations/`.
Local GRDB shapes: `apps/ios/Tickytacky/Data/Models/` + `Migrations.swift`.

## Ownership

| Concern | Rule |
|---------|------|
| `user_id` | Required on every remote row. Local cache omits it; SyncEngine injects `auth.uid()` on push. |
| Soft-delete | Both sides use `deleted_at`. Hard-purge via `purge_soft_deleted()` after 30 days. |
| LWW | Per-record by `updated_at`. Local dirty when `synced_at` is nil or `updated_at > synced_at`. |
| Trigger | `20260819000005_lww_updated_at.sql` preserves client-supplied `updated_at` on UPDATE. |
| Compact | `20260819000006_storage_compact.sql` — drop unused cols, nullable recurrence, smallints, text bounds. |

## lists

| Local | Remote | Notes |
|-------|--------|-------|
| id | id | UUID (lowercase) |
| name, color, is_inbox, sort_order | same | `sort_order` smallint; color ≤16 chars |
| icon | — | **Local-only** (dropped from cloud) |
| created_at / updated_at / deleted_at | same | |
| — | user_id | Inject on push |

## tasks

| Local | Remote | Notes |
|-------|--------|-------|
| due_date (start-of-day Date) | due_date (DATE) | Format `yyyy-MM-dd` |
| has_due_time + due_hour/due_minute | due_time (TIME) | `HH:mm:ss` or null |
| priority Int 0…4 | priority enum | |
| recurrence_json | recurrence_frequency / interval / start | Interval **null** when non-recurring |
| byWeekdays in JSON | — | Not synced (MVP) |
| list_id NOT NULL | list_id nullable | Pull null → Inbox |
| reminder_offsets_json | — | **Local-only** |
| title / notes | same | Caps 280 / 8000; empty → null |

## subtasks / tags

Straightforward; title/name length-capped; colors ≤16 chars.

## task_tags

No `updated_at` / `deleted_at` (hard links). Replace-set sync per dirty task.

## schedules

| Local | Remote | Notes |
|-------|--------|-------|
| timezone | — | **Local-only** |
| color, is_active, name | same | |

## schedule_blocks

| Local | Remote | Notes |
|-------|--------|-------|
| weekday | iso_weekday | Calendar ↔ ISO |
| start/end hour+minute | start_time / end_time | |
| color | color | ≤16 chars |
| tag_id | — | Dropped from cloud |
| reminder_minutes_before | same | smallint |

## schedule_exceptions

type + original_start / new_start / new_end; notes ≤500.

## Cloud storage ops

```sql
-- Bound soft-delete growth (service_role / SQL editor / cron)
select * from public.purge_soft_deleted(interval '30 days');
```

See `supabase/README.md` §Storage.
