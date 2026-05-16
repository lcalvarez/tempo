-- Add `partnerships` to the realtime publication so paired clients can
-- react to insert/update/delete events instantly. The primary motivation
-- is cross-device unpair: when one side deletes the partnership row,
-- the other side's app should flip to the "solo" UI immediately, not on
-- the next foreground refresh.
--
-- RLS continues to gate what each subscriber sees: realtime delivers
-- the same rows that `select` would have returned. The existing
-- `partnerships: read own` policy (`auth.uid() in (user_a, user_b)`)
-- means each user only receives events for their own partnership row.
--
-- We also need REPLICA IDENTITY FULL so DELETE events carry the row's
-- columns (default `default` only sends the primary key, which is fine
-- for matching but loses context — having both ids handy lets clients
-- reason about which side initiated, log helpfully, etc.).

alter table public.partnerships replica identity full;

alter publication supabase_realtime add table public.partnerships;
