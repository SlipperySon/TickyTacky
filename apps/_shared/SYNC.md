# Cross-client sync

Same hosted project: `https://fgdmonniblfzapdpxfxc.supabase.co`.

## Auth: sync key from the Apple app

1. On iPhone or Mac: Settings → **Create sync key**. Copy the `TTK-…` value (shown once).
2. On Web / Android / Windows: Settings → paste the key → Connect.
3. All clients share the same `auth.users` row, so RLS (`user_id = auth.uid()`) and Apple `SyncEngine` see the same data.

The key is stored hashed (`sync_keys`). Redeem/issue is the `sync-key` Edge Function. Sign in with Apple remains optional.

Public URL + anon key: [`supabase-public.json`](supabase-public.json) (never ship the service role).

## Data

Minimum viable on non-Apple shells: Inbox + tasks. Full field map: [`apps/ios/.../SyncMapping.md`](../ios/Tickytacky/Data/Sync/SyncMapping.md).
