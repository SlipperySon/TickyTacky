-- Tickytacky — local seed data (loaded by `supabase db reset`).
-- Creates one demo user and a small, realistic dataset so Studio/Today have
-- something to show during local development. NOT used in production.
--
-- Demo login (local only):  demo@tickytacky.app  /  tickytacky

-- ---------------------------------------------------------------------------
-- Demo auth user (fixed id so seeded rows can reference it).
-- ---------------------------------------------------------------------------
insert into auth.users (
  instance_id, id, aud, role, email,
  encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at,
  -- GoTrue scans these token columns as non-null strings; NULLs cause a
  -- "Database error querying schema" on login, so seed them as ''.
  confirmation_token, recovery_token, email_change, email_change_token_new
)
values (
  '00000000-0000-0000-0000-000000000000',
  '11111111-1111-1111-1111-111111111111',
  'authenticated', 'authenticated', 'demo@tickytacky.app',
  crypt('tickytacky', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}', '{}',
  now(), now(),
  '', '', '', ''
)
on conflict (id) do nothing;

-- Email identity so the demo user can actually sign in with a password locally.
insert into auth.identities (
  provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
)
values (
  '11111111-1111-1111-1111-111111111111',
  '11111111-1111-1111-1111-111111111111',
  '{"sub":"11111111-1111-1111-1111-111111111111","email":"demo@tickytacky.app","email_verified":true}',
  'email', now(), now(), now()
)
on conflict (provider, provider_id) do nothing;

-- ---------------------------------------------------------------------------
-- App data for the demo user.
-- ---------------------------------------------------------------------------
do $$
declare
  uid          uuid := '11111111-1111-1111-1111-111111111111';
  inbox_id     uuid;
  course_id    uuid;
  tag_school   uuid;
  work_sched   uuid;
begin
  -- Lists
  insert into public.lists (user_id, name, is_inbox, sort_order)
    values (uid, 'Inbox', true, 0) returning id into inbox_id;
  insert into public.lists (user_id, name, color, sort_order)
    values (uid, 'Coursework', 'sky', 1) returning id into course_id;

  -- Tag
  insert into public.tags (user_id, name, color)
    values (uid, 'school', 'sage') returning id into tag_school;

  -- Tasks
  insert into public.tasks (user_id, list_id, title, priority, due_date)
    values (uid, inbox_id, 'Finish Tickytacky Phase A foundation', 'high', current_date);

  insert into public.tasks (user_id, list_id, title, priority, due_date)
    values (uid, inbox_id, 'Wire GRDB local cache', 'medium', current_date + 1);

  -- A recurring task (weekly) linked to a tag.
  declare rls_task uuid;
  begin
    insert into public.tasks (
      user_id, list_id, title, priority, due_date,
      recurrence_frequency, recurrence_interval, recurrence_start
    )
    values (
      uid, course_id, 'Read Supabase RLS docs', 'low', current_date + 2,
      'weekly', 1, current_date + 2
    )
    returning id into rls_task;

    insert into public.task_tags (task_id, tag_id, user_id)
      values (rls_task, tag_school, uid);
  end;

  -- Timetable: a "Work Week" schedule with two weekly blocks.
  insert into public.schedules (user_id, name, is_active, color)
    values (uid, 'Work Week', true, 'Kraft') returning id into work_sched;

  insert into public.schedule_blocks (user_id, schedule_id, title, iso_weekday, start_time, end_time, color, reminder_minutes_before)
    values (uid, work_sched, 'Deep Work', 1, '09:00', '11:00', 'Sage', 10);

  insert into public.schedule_blocks (user_id, schedule_id, title, iso_weekday, start_time, end_time, color, list_id)
    values (uid, work_sched, 'CHEM 101', 3, '13:00', '14:30', 'Sky', course_id);
end
$$;
