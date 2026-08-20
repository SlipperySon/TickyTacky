-- Storage compaction: shrink row width, drop unused columns, bound text,
-- tighten indexes, and purge soft-deleted rows so cloud growth stays bounded.
-- Safe to apply on existing DBs (ALTER / DROP). Fresh resets include this via order.

-- ---------------------------------------------------------------------------
-- 1. Drop cloud columns unused by the Apple client (MVP)
-- ---------------------------------------------------------------------------
-- recurrence_end / by_weekdays: not in local RecurrenceRule MVP path
alter table public.tasks drop column if exists recurrence_end;
alter table public.tasks drop column if exists recurrence_by_weekdays;

-- schedule_blocks.tag_id: never pushed/pulled by SyncEngine
alter table public.schedule_blocks drop column if exists tag_id;

-- lists.icon: unused in UI; keep name/color only on cloud
alter table public.lists drop column if exists icon;

-- ---------------------------------------------------------------------------
-- 2. Stop paying 4 bytes on every non-recurring task
-- ---------------------------------------------------------------------------
alter table public.tasks
  alter column recurrence_interval drop not null,
  alter column recurrence_interval drop default;

update public.tasks
set recurrence_interval = null
where recurrence_frequency is null;

alter table public.tasks
  drop constraint if exists tasks_recurrence_needs_start;

alter table public.tasks
  add constraint tasks_recurrence_shape check (
    (recurrence_frequency is null
      and recurrence_interval is null
      and recurrence_start is null)
    or (recurrence_frequency is not null
      and recurrence_interval is not null
      and recurrence_interval >= 1
      and recurrence_start is not null)
  );

-- ---------------------------------------------------------------------------
-- 3. Smaller numeric types
-- ---------------------------------------------------------------------------
alter table public.lists
  alter column sort_order type smallint using sort_order::smallint;

alter table public.tasks
  alter column sort_order type smallint using sort_order::smallint;

alter table public.subtasks
  alter column sort_order type smallint using sort_order::smallint;

alter table public.schedule_blocks
  alter column reminder_minutes_before type smallint
  using reminder_minutes_before::smallint;

-- ---------------------------------------------------------------------------
-- 4. Bound text / colors (prevent accidental TOAST bloat)
-- ---------------------------------------------------------------------------
-- Empty strings → NULL (NULL is cheaper than '')
update public.lists set color = null where color is not null and btrim(color) = '';
update public.tags set color = null where color is not null and btrim(color) = '';
update public.schedules set color = null where color is not null and btrim(color) = '';
update public.schedule_blocks set color = null where color is not null and btrim(color) = '';
update public.tasks set notes = null where notes is not null and notes = '';
update public.schedule_blocks set notes = null where notes is not null and notes = '';
update public.schedule_exceptions set notes = null where notes is not null and notes = '';

alter table public.lists
  drop constraint if exists lists_name_len,
  drop constraint if exists lists_color_len;
alter table public.lists
  add constraint lists_name_len check (char_length(name) <= 120),
  add constraint lists_color_len check (color is null or char_length(color) <= 16);

alter table public.tags
  drop constraint if exists tags_name_len,
  drop constraint if exists tags_color_len;
alter table public.tags
  add constraint tags_name_len check (char_length(name) <= 64),
  add constraint tags_color_len check (color is null or char_length(color) <= 16);

alter table public.tasks
  drop constraint if exists tasks_title_len,
  drop constraint if exists tasks_notes_len;
alter table public.tasks
  add constraint tasks_title_len check (char_length(title) <= 280),
  add constraint tasks_notes_len check (notes is null or char_length(notes) <= 8000);

alter table public.subtasks
  drop constraint if exists subtasks_title_len;
alter table public.subtasks
  add constraint subtasks_title_len check (char_length(title) <= 280);

alter table public.schedules
  drop constraint if exists schedules_name_len,
  drop constraint if exists schedules_color_len;
alter table public.schedules
  add constraint schedules_name_len check (char_length(name) <= 120),
  add constraint schedules_color_len check (color is null or char_length(color) <= 16);

alter table public.schedule_blocks
  drop constraint if exists schedule_blocks_title_len,
  drop constraint if exists schedule_blocks_notes_len,
  drop constraint if exists schedule_blocks_color_len;
alter table public.schedule_blocks
  add constraint schedule_blocks_title_len check (char_length(title) <= 160),
  add constraint schedule_blocks_notes_len check (notes is null or char_length(notes) <= 2000),
  add constraint schedule_blocks_color_len check (color is null or char_length(color) <= 16);

alter table public.schedule_exceptions
  drop constraint if exists schedule_exceptions_notes_len;
alter table public.schedule_exceptions
  add constraint schedule_exceptions_notes_len check (notes is null or char_length(notes) <= 500);

-- ---------------------------------------------------------------------------
-- 5. Index hygiene (indexes are cloud storage too)
-- ---------------------------------------------------------------------------
-- Low-selectivity full incomplete index → only incomplete live tasks
drop index if exists public.tasks_user_incomplete_idx;
create index tasks_user_incomplete_idx
  on public.tasks (user_id)
  where deleted_at is null and is_completed = false;

-- task_tags_user_idx mostly for RLS scans; keep but make it covering less
-- (user_id alone is enough; drop redundant tag-only if unused — keep tag_idx for "tasks with tag")

-- ---------------------------------------------------------------------------
-- 6. Soft-delete purge (largest long-term savings)
-- ---------------------------------------------------------------------------
-- Hard-deletes rows soft-deleted longer than p_older_than (default 30 days).
-- Run via Supabase cron / Edge / SQL editor, e.g.:
--   select * from public.purge_soft_deleted(interval '30 days');
create or replace function public.purge_soft_deleted(p_older_than interval default interval '30 days')
returns table(entity text, purged bigint)
language plpgsql
security definer
set search_path = public
as $$
declare
  cutoff timestamptz := now() - p_older_than;
begin
  -- Children before parents where FKs require it (exceptions → blocks → schedules;
  -- subtasks/task_tags cascade from tasks, but purge explicitly for counts).
  return query
  with del_exc as (
    delete from public.schedule_exceptions
    where deleted_at is not null and deleted_at < cutoff
    returning 1
  )
  select 'schedule_exceptions'::text, count(*)::bigint from del_exc;

  return query
  with del_blocks as (
    delete from public.schedule_blocks
    where deleted_at is not null and deleted_at < cutoff
    returning 1
  )
  select 'schedule_blocks'::text, count(*)::bigint from del_blocks;

  return query
  with del_sched as (
    delete from public.schedules
    where deleted_at is not null and deleted_at < cutoff
    returning 1
  )
  select 'schedules'::text, count(*)::bigint from del_sched;

  return query
  with del_sub as (
    delete from public.subtasks
    where deleted_at is not null and deleted_at < cutoff
    returning 1
  )
  select 'subtasks'::text, count(*)::bigint from del_sub;

  -- task_tags has no deleted_at; orphans go away with task delete cascade
  return query
  with del_tasks as (
    delete from public.tasks
    where deleted_at is not null and deleted_at < cutoff
    returning 1
  )
  select 'tasks'::text, count(*)::bigint from del_tasks;

  return query
  with del_tags as (
    delete from public.tags
    where deleted_at is not null and deleted_at < cutoff
    returning 1
  )
  select 'tags'::text, count(*)::bigint from del_tags;

  return query
  with del_lists as (
    delete from public.lists
    where deleted_at is not null and deleted_at < cutoff
      and is_inbox = false  -- never hard-delete Inbox tombstones needed for sync edge cases
    returning 1
  )
  select 'lists'::text, count(*)::bigint from del_lists;
end;
$$;

revoke all on function public.purge_soft_deleted(interval) from public;
grant execute on function public.purge_soft_deleted(interval) to service_role;

comment on function public.purge_soft_deleted(interval) is
  'Hard-delete soft-deleted rows older than the interval. Call periodically to bound cloud storage.';
