-- Tickytacky — foundational helpers, extensions, and enum types.
-- See IMPLEMENTATION_MAP.md §3 (domain model) and MEM.md (locked decisions:
-- soft-delete, last-write-wins per record via updated_at, user-scoped rows).

-- gen_random_uuid() lives in pgcrypto (available by default on Supabase).
create extension if not exists pgcrypto;

-- Keeps updated_at fresh on every UPDATE so clients can do last-write-wins.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Priority levels (SCOPE.md / DESIGN.md): none / low / medium / high / urgent.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'task_priority') then
    create type public.task_priority as enum ('none', 'low', 'medium', 'high', 'urgent');
  end if;
end
$$;

-- Recurrence frequency for recurring tasks (MVP set).
do $$
begin
  if not exists (select 1 from pg_type where typname = 'recurrence_frequency') then
    create type public.recurrence_frequency as enum ('daily', 'weekly', 'monthly', 'yearly');
  end if;
end
$$;

-- Schedule exception kinds (skip a slot, or move a single occurrence).
do $$
begin
  if not exists (select 1 from pg_type where typname = 'schedule_exception_type') then
    create type public.schedule_exception_type as enum ('skip', 'reschedule');
  end if;
end
$$;
