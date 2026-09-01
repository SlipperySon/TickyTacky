-- Pairing keys issued from the Apple app so Web / Android / Windows can
-- join the same auth.users row without Sign in with Apple or email.

create table public.sync_keys (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  key_hash     text not null unique,
  created_at   timestamptz not null default now(),
  last_used_at timestamptz,
  revoked_at   timestamptz
);

create index sync_keys_user_active_idx
  on public.sync_keys (user_id)
  where revoked_at is null;

alter table public.sync_keys enable row level security;
alter table public.sync_keys force row level security;

-- Clients never read hashes. Issue/redeem goes through the sync-key Edge Function
-- (service_role). Authenticated users may list/revoke their own rows.
create policy sync_keys_owner_select on public.sync_keys
  for select to authenticated
  using (user_id = auth.uid());

create policy sync_keys_owner_update on public.sync_keys
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select, update on public.sync_keys to authenticated;
grant all on public.sync_keys to service_role;
