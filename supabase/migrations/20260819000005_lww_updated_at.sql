-- Client LWW sync: preserve caller-supplied updated_at on UPDATE.
-- Auto-bump only when the client left updated_at unchanged (Studio / casual SQL).
-- Required for SyncEngine last-write-wins (Phase H5); without this, the previous
-- trigger always overwrote updated_at with now() and destroyed client timestamps.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  if new.updated_at is not distinct from old.updated_at then
    new.updated_at = now();
  end if;
  return new;
end;
$$;
