-- ────────────────────────────────────────────────────────────────────────
-- profiles: appearance + custom stretch areas
-- ────────────────────────────────────────────────────────────────────────
--
-- v1 of the schema didn't include the user's UI preferences or their custom
-- stretching list. Both are small, single-user-scoped values, so they live
-- on the profile row directly rather than getting their own tables.
-- Custom *exercises* will land in a separate phase as their own table since
-- they need joins from sessions.

alter table public.profiles
  add column if not exists appearance            text   not null default 'system'
    check (appearance in ('system','light','dark')),
  add column if not exists custom_stretch_areas  text[] not null default '{}';
