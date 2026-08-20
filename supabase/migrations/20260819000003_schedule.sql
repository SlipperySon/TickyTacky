-- Tickytacky — timetable entities: schedules, schedule_blocks, exceptions.
-- Blocks are recurring weekly slots (first-class, NOT tasks — locked D5).
-- Occurrences are computed client-side; only exceptions are stored (D6).

-- ---------------------------------------------------------------------------
-- Schedule = a named timetable (e.g. "Semester 1", "Work Week").
-- ---------------------------------------------------------------------------
create table public.schedules (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  name        text not null check (length(trim(name)) > 0),
  is_active   boolean not null default true,
  color       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

create index schedules_user_active_idx
  on public.schedules (user_id)
  where deleted_at is null;

create trigger schedules_set_updated_at
  before update on public.schedules
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- ScheduleBlock = a recurring weekly time block on one weekday.
-- MVP: no overnight spans (end_time > start_time enforced).
-- ---------------------------------------------------------------------------
create table public.schedule_blocks (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  schedule_id   uuid not null references public.schedules (id) on delete cascade,
  title         text not null check (length(trim(title)) > 0),
  notes         text,
  iso_weekday   smallint not null check (iso_weekday between 1 and 7),  -- 1=Mon..7=Sun
  start_time    time not null,
  end_time      time not null,
  color         text,
  list_id       uuid references public.lists (id) on delete set null,
  tag_id        uuid references public.tags (id) on delete set null,
  reminder_minutes_before integer check (reminder_minutes_before >= 0),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  constraint schedule_blocks_end_after_start check (end_time > start_time)
);

create index schedule_blocks_lookup_idx
  on public.schedule_blocks (user_id, schedule_id, iso_weekday)
  where deleted_at is null;

create trigger schedule_blocks_set_updated_at
  before update on public.schedule_blocks
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- ScheduleException = a one-off skip/move for a single generated occurrence.
-- original_start identifies which occurrence the exception applies to.
-- ---------------------------------------------------------------------------
create table public.schedule_exceptions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users (id) on delete cascade,
  block_id        uuid not null references public.schedule_blocks (id) on delete cascade,
  original_start  timestamptz not null,
  type            public.schedule_exception_type not null,
  new_start       timestamptz,
  new_end         timestamptz,
  notes           text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz,
  -- A reschedule must provide the new window; a skip must not.
  constraint schedule_exceptions_reschedule_window check (
    (type = 'reschedule' and new_start is not null and new_end is not null and new_end > new_start)
    or (type = 'skip' and new_start is null and new_end is null)
  )
);

-- One live exception per (block, occurrence).
create unique index schedule_exceptions_unique_occurrence
  on public.schedule_exceptions (block_id, original_start)
  where deleted_at is null;

create trigger schedule_exceptions_set_updated_at
  before update on public.schedule_exceptions
  for each row execute function public.set_updated_at();
