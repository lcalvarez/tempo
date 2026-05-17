-- plan_generation_log
--
-- Defense-in-depth rate limiter for the `generate-plan` Edge Function:
-- one Anthropic-backed plan generation per (user, local-day) pair. The
-- iOS client also caches once per day on-device (PlannedDayCache.swift),
-- so this table only matters when:
--
--   • a fresh install bypasses the device cache, OR
--   • the user wipes the cache via "Reset" in Profile → Debug, OR
--   • the user has multiple devices.
--
-- Without this table, the Sonnet bill would scale linearly with the
-- number of times an authenticated user retaps "Regenerate" within a
-- day. With it, hitting the rate limit returns HTTP 429, the iOS
-- provider catches that and falls through to the heuristic — same
-- end-state as a network failure, no surprise spend.
--
-- Why a per-day row rather than a counter on `profiles`:
-- • A row stays around for analytics ("how often does the AI tier get
--   used in practice?") without us having to add another column.
-- • The unique (user_id, day_key) constraint serves as the rate limit
--   directly — `insert ... on conflict do nothing` is the natural
--   "did we already log one today?" check.

create table if not exists public.plan_generation_log (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references auth.users (id) on delete cascade,
    -- Local-day key in 'YYYY-MM-DD'. Computed by the Edge Function from
    -- the request time (UTC); a small overlap at midnight is fine since
    -- the on-device cache is the primary gate.
    day_key     text not null,
    created_at  timestamptz not null default now(),
    unique (user_id, day_key)
);

-- RLS: users can read their own log entries (useful for a future
-- "you've used your AI plan today" UI), but only the service-role
-- (used by the Edge Function) can insert / delete. The Edge Function
-- runs with the service role key, bypassing RLS by design.
alter table public.plan_generation_log enable row level security;

create policy "plan_generation_log: read own"
    on public.plan_generation_log for select
    using (user_id = auth.uid());

-- No insert/update/delete policies for `authenticated` — the Edge
-- Function uses the service role and is the only writer.
