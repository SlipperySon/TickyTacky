-- Tickytacky — Row Level Security. Every row is owned by user_id; an
-- authenticated user may only touch their own rows. service_role (used by
-- server-side sync/admin) bypasses RLS. anon has no access to user data.

grant usage on schema public to authenticated, service_role;

do $$
declare
  tbl text;
  tables text[] := array[
    'lists', 'tags', 'tasks', 'subtasks', 'task_tags',
    'schedules', 'schedule_blocks', 'schedule_exceptions'
  ];
begin
  foreach tbl in array tables loop
    execute format('alter table public.%I enable row level security;', tbl);
    -- Force RLS so even the table owner is subject to policies.
    execute format('alter table public.%I force row level security;', tbl);

    execute format(
      'create policy %I on public.%I for all to authenticated '
      || 'using (user_id = auth.uid()) with check (user_id = auth.uid());',
      tbl || '_owner_all', tbl
    );

    execute format(
      'grant select, insert, update, delete on public.%I to authenticated, service_role;',
      tbl
    );
  end loop;
end
$$;
