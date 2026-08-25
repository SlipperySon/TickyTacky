-- Tickytacky — same-owner FK integrity under RLS.
-- Prevents authenticated users from attaching rows to another user's
-- lists/tasks/tags/schedules (and blocks task_tags PK squatting).

-- tasks.list_id must belong to the same user
drop policy if exists tasks_owner_all on public.tasks;
create policy tasks_owner_all on public.tasks
  for all to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.lists l
      where l.id = list_id and l.user_id = auth.uid()
    )
  );

-- subtasks.task_id
drop policy if exists subtasks_owner_all on public.subtasks;
create policy subtasks_owner_all on public.subtasks
  for all to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.tasks t
      where t.id = task_id and t.user_id = auth.uid()
    )
  );

-- task_tags: both endpoints owned by caller
drop policy if exists task_tags_owner_all on public.task_tags;
create policy task_tags_owner_all on public.task_tags
  for all to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.tasks t
      where t.id = task_id and t.user_id = auth.uid()
    )
    and exists (
      select 1 from public.tags g
      where g.id = tag_id and g.user_id = auth.uid()
    )
  );

-- schedule_blocks.schedule_id (+ optional list_id)
drop policy if exists schedule_blocks_owner_all on public.schedule_blocks;
create policy schedule_blocks_owner_all on public.schedule_blocks
  for all to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.schedules s
      where s.id = schedule_id and s.user_id = auth.uid()
    )
    and (
      list_id is null
      or exists (
        select 1 from public.lists l
        where l.id = list_id and l.user_id = auth.uid()
      )
    )
  );

-- schedule_exceptions.block_id
drop policy if exists schedule_exceptions_owner_all on public.schedule_exceptions;
create policy schedule_exceptions_owner_all on public.schedule_exceptions
  for all to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.schedule_blocks b
      where b.id = block_id and b.user_id = auth.uid()
    )
  );
