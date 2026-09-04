-- Hashes must not be readable over the Data API. Edge Functions use service_role.
drop policy if exists sync_keys_owner_select on public.sync_keys;
drop policy if exists sync_keys_owner_update on public.sync_keys;

revoke all on table public.sync_keys from anon, authenticated, public;
grant all on table public.sync_keys to service_role;
grant all on table public.sync_keys to postgres;

create table if not exists public.sync_key_rate_limits (
  bucket text primary key,
  window_started_at timestamptz not null default now(),
  hit_count integer not null default 0
);

comment on table public.sync_key_rate_limits is
  'Per-IP windows for sync-key issue/redeem. Service role only.';

alter table public.sync_key_rate_limits enable row level security;
alter table public.sync_key_rate_limits force row level security;

revoke all on table public.sync_key_rate_limits from anon, authenticated, public;
grant all on table public.sync_key_rate_limits to service_role;
grant all on table public.sync_key_rate_limits to postgres;

revoke all on function public.purge_soft_deleted(interval) from public, anon, authenticated;
grant execute on function public.purge_soft_deleted(interval) to service_role;
