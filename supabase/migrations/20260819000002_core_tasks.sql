-- Tickytacky — core task entities: lists, tasks, subtasks, tags, task_tags.
-- All rows are user-scoped (user_id -> auth.users) for RLS, carry updated_at
-- for last-write-wins sync, and use deleted_at for soft-delete.

-- ---------------------------------------------------------------------------
-- Lists (projects/folders). Exactly one Inbox per user.
-- ---------------------------------------------------------------------------
create table public.lists (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  name        text not null check (length(trim(name)) > 0),
  color       text,
  icon        text,
  is_inbox    boolean not null default false,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

-- At most one live Inbox per user.
create unique index lists_one_inbox_per_user
  on public.lists (user_id)
  where is_inbox and deleted_at is null;

create index lists_user_active_idx
  on public.lists (user_id)
  where deleted_at is null;

create trigger lists_set_updated_at
  before update on public.lists
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Tags (many-to-many with tasks). Case-insensitive unique name per user.
-- ---------------------------------------------------------------------------
create table public.tags (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  name        text not null check (length(trim(name)) > 0),
  color       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

create unique index tags_unique_name_per_user
  on public.tags (user_id, lower(name))
  where deleted_at is null;

create trigger tags_set_updated_at
  before update on public.tags
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Tasks. Recurrence rule is embedded (series-only in MVP; see MEM.md).
-- ---------------------------------------------------------------------------
create table public.tasks (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  list_id       uuid references public.lists (id) on delete set null,
  title         text not null check (length(trim(title)) > 0),
  notes         text,
  is_completed  boolean not null default false,
  completed_at  timestamptz,
  due_date      date,
  due_time      time,
  priority      public.task_priority not null default 'none',
  sort_order    integer not null default 0,
  -- Embedded recurrence rule (all null = non-recurring).
  recurrence_frequency   public.recurrence_frequency,
  recurrence_interval    integer not null default 1 check (recurrence_interval >= 1),
  recurrence_by_weekdays smallint[],  -- ISO weekdays 1=Mon..7=Sun (P1 custom weekly)
  recurrence_start       date,
  recurrence_end         date,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  constraint tasks_recurrence_needs_start
    check (recurrence_frequency is null or recurrence_start is not null)
);

create index tasks_user_due_idx
  on public.tasks (user_id, due_date)
  where deleted_at is null;

create index tasks_user_list_idx
  on public.tasks (user_id, list_id)
  where deleted_at is null;

create index tasks_user_incomplete_idx
  on public.tasks (user_id, is_completed)
  where deleted_at is null;

create trigger tasks_set_updated_at
  before update on public.tasks
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Subtasks (checklist items under a task).
-- ---------------------------------------------------------------------------
create table public.subtasks (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  task_id       uuid not null references public.tasks (id) on delete cascade,
  title         text not null check (length(trim(title)) > 0),
  is_completed  boolean not null default false,
  sort_order    integer not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz
);

create index subtasks_task_idx
  on public.subtasks (task_id)
  where deleted_at is null;

create trigger subtasks_set_updated_at
  before update on public.subtasks
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Task <-> Tag join. user_id denormalized so RLS is a simple owner check.
-- ---------------------------------------------------------------------------
create table public.task_tags (
  task_id     uuid not null references public.tasks (id) on delete cascade,
  tag_id      uuid not null references public.tags (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (task_id, tag_id)
);

create index task_tags_tag_idx on public.task_tags (tag_id);
create index task_tags_user_idx on public.task_tags (user_id);
