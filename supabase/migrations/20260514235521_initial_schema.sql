-- Tempo · initial schema
--
-- Applied automatically by `supabase db reset` (locally) and
-- `supabase db push` (cloud). Idempotent for safety in case of replays.
--
-- Tables:
--   profiles      1:1 with auth.users; user-facing identity + goals
--   pair_invites  short-lived codes/tokens for partner pairing
--   partnerships  canonical (user_a < user_b) edges
--   sessions      a completed workout
--   exercises     ordered list of exercises within a session
--   sets          ordered list of sets within an exercise
--   live_sessions ephemeral state for realtime partner viewing
--
-- All tables have RLS enabled. Users see their own data + (where applicable)
-- their paired partner's profile and live session.

-- ────────────────────────────────────────────────────────────────────────
-- extensions
-- ────────────────────────────────────────────────────────────────────────

create extension if not exists "pgcrypto"  with schema extensions;
create extension if not exists "uuid-ossp" with schema extensions;

-- ────────────────────────────────────────────────────────────────────────
-- profiles
-- ────────────────────────────────────────────────────────────────────────

create table if not exists public.profiles (
  id                          uuid primary key references auth.users on delete cascade,
  name                        text default '',
  age                         int  default 0,
  units                       text default 'imperial' check (units in ('imperial','metric')),
  fitness_level               text default 'some'     check (fitness_level in ('new','some','strong','advanced')),
  monogram_tone               text default 'you',
  equipment                   text[] default '{}',
  preferred_workout_times     text[] default '{}',
  injuries                    text default '',
  focuses                     text[] default '{strength,hypertrophy}',
  sessions_per_week           int    default 4 check (sessions_per_week between 1 and 14),
  intensity                   text   default 'moderate' check (intensity in ('easy','moderate','hard','brutal')),
  enjoyed_styles              text[] default '{}',
  avoided_styles              text[] default '{}',
  planning_mode               text   default 'ai' check (planning_mode in ('ai','manual')),
  manual_exercise_ids         text[] default '{}',
  has_onboarded               boolean default false,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now()
);

create or replace function public.tg_set_updated_at() returns trigger
language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute procedure public.tg_set_updated_at();

-- Auto-create a profile row whenever a new auth.users row appears.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id) values (new.id) on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;

drop policy if exists "profiles: read own"        on public.profiles;
drop policy if exists "profiles: read partner"    on public.profiles;
drop policy if exists "profiles: update own"      on public.profiles;
drop policy if exists "profiles: insert own"      on public.profiles;

create policy "profiles: read own"
  on public.profiles for select
  using (id = auth.uid());

create policy "profiles: update own"
  on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "profiles: insert own"
  on public.profiles for insert
  with check (id = auth.uid());

-- "profiles: read partner" is created *after* the partnerships table exists
-- (see below). Postgres validates the policy USING expression at creation
-- time, so the referenced relation must already be defined.

-- ────────────────────────────────────────────────────────────────────────
-- partnerships  (symmetric, canonical ordering enforced)
-- ────────────────────────────────────────────────────────────────────────

-- `user_a_label` is what user_a calls user_b ("my wife"), `user_b_label` is
-- the reverse ("my husband"). Free-form text so we can support 'Other…'
-- entries; canonical values match the `RelationshipLabel` Swift enum:
--   wife | husband | spouse | partner | friend | sibling |
--   parent | child | trainer | other (with custom text in *_label_custom)
create table if not exists public.partnerships (
  id                   uuid primary key default gen_random_uuid(),
  user_a               uuid not null references public.profiles on delete cascade,
  user_b               uuid not null references public.profiles on delete cascade,
  paired_since         timestamptz not null default now(),
  user_a_label         text,
  user_a_label_custom  text,
  user_b_label         text,
  user_b_label_custom  text,
  check (user_a < user_b),
  unique (user_a, user_b)
);

alter table public.partnerships enable row level security;

drop policy if exists "partnerships: read own" on public.partnerships;
drop policy if exists "partnerships: delete own" on public.partnerships;

create policy "partnerships: read own"
  on public.partnerships for select
  using (auth.uid() in (user_a, user_b));

create policy "partnerships: delete own"
  on public.partnerships for delete
  using (auth.uid() in (user_a, user_b));

-- Cross-table policy: a user can read their partner's profile. Defined here
-- (instead of next to the other profile policies) because it references the
-- partnerships table, which must exist before the policy is created.
create policy "profiles: read partner"
  on public.profiles for select
  using (
    exists (
      select 1 from public.partnerships p
      where (p.user_a = auth.uid() and p.user_b = profiles.id)
         or (p.user_b = auth.uid() and p.user_a = profiles.id)
    )
  );

-- Each side can only set the column corresponding to *their* relationship to
-- the other person. Implemented as a SECURITY DEFINER RPC so we don't need a
-- column-conditional UPDATE policy.
create or replace function public.set_relationship_label(
  p_partnership_id uuid,
  p_label          text,
  p_label_custom   text default null
) returns public.partnerships
language plpgsql security definer set search_path = public as $$
declare
  result public.partnerships;
  row    public.partnerships;
begin
  if auth.uid() is null then raise exception 'must be authenticated'; end if;

  select * into row from public.partnerships where id = p_partnership_id;
  if not found then raise exception 'partnership not found'; end if;

  if auth.uid() = row.user_a then
    update public.partnerships
       set user_a_label = p_label, user_a_label_custom = p_label_custom
     where id = p_partnership_id
     returning * into result;
  elsif auth.uid() = row.user_b then
    update public.partnerships
       set user_b_label = p_label, user_b_label_custom = p_label_custom
     where id = p_partnership_id
     returning * into result;
  else
    raise exception 'not a member of this partnership';
  end if;

  return result;
end;
$$;

revoke all on function public.set_relationship_label(uuid, text, text) from public;
grant execute on function public.set_relationship_label(uuid, text, text) to authenticated;

-- Inserts happen exclusively via the accept_pair_invite() SECURITY DEFINER
-- function below, so no insert policy is needed.

-- ────────────────────────────────────────────────────────────────────────
-- pair_invites
-- ────────────────────────────────────────────────────────────────────────

create table if not exists public.pair_invites (
  id            uuid primary key default gen_random_uuid(),
  from_user     uuid not null references public.profiles on delete cascade,
  code          text not null unique,        -- e.g. 'A3X9KP'
  token         text not null unique,        -- 32-char for deep links
  created_at    timestamptz not null default now(),
  expires_at    timestamptz not null default (now() + interval '24 hours'),
  accepted_by   uuid references public.profiles,
  accepted_at   timestamptz
);

create index if not exists pair_invites_code_idx  on public.pair_invites (code)  where accepted_at is null;
create index if not exists pair_invites_token_idx on public.pair_invites (token) where accepted_at is null;

alter table public.pair_invites enable row level security;

drop policy if exists "invites: read own" on public.pair_invites;
create policy "invites: read own"
  on public.pair_invites for select
  using (from_user = auth.uid() or accepted_by = auth.uid());

-- Generate a fresh code+token for the calling user. Invalidates any previous
-- open invites from this user.
create or replace function public.create_pair_invite()
returns public.pair_invites
language plpgsql security definer set search_path = public as $$
declare
  new_code  text;
  new_token text;
  result    public.pair_invites;
  alphabet  constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  i int;
begin
  if auth.uid() is null then raise exception 'must be authenticated'; end if;

  update public.pair_invites
     set expires_at = now()
   where from_user = auth.uid() and accepted_at is null and expires_at > now();

  new_code := '';
  for i in 1..6 loop
    new_code := new_code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
  end loop;

  new_token := encode(extensions.gen_random_bytes(24), 'base64');
  new_token := translate(new_token, '+/=', '-_');

  insert into public.pair_invites (from_user, code, token)
       values (auth.uid(), new_code, new_token)
    returning * into result;
  return result;
end;
$$;

revoke all on function public.create_pair_invite() from public;
grant execute on function public.create_pair_invite() to authenticated;

create or replace function public.accept_pair_invite(p_code text default null, p_token text default null)
returns public.partnerships
language plpgsql security definer set search_path = public as $$
declare
  inv         public.pair_invites;
  a uuid; b uuid;
  result      public.partnerships;
begin
  if auth.uid() is null then raise exception 'must be authenticated'; end if;
  if p_code is null and p_token is null then raise exception 'code or token required'; end if;

  select * into inv from public.pair_invites
    where (p_code  is not null and code  = upper(p_code))
       or (p_token is not null and token = p_token)
    limit 1;

  if not found then raise exception 'invite not found'; end if;
  if inv.accepted_at is not null then raise exception 'invite already accepted'; end if;
  if inv.expires_at < now() then raise exception 'invite expired'; end if;
  if inv.from_user = auth.uid() then raise exception 'cannot accept your own invite'; end if;

  if inv.from_user < auth.uid() then a := inv.from_user; b := auth.uid();
  else                                a := auth.uid();   b := inv.from_user; end if;

  insert into public.partnerships (user_a, user_b)
       values (a, b)
  on conflict (user_a, user_b) do update set paired_since = excluded.paired_since
    returning * into result;

  update public.pair_invites
     set accepted_by = auth.uid(), accepted_at = now()
   where id = inv.id;

  return result;
end;
$$;

revoke all on function public.accept_pair_invite(text, text) from public;
grant execute on function public.accept_pair_invite(text, text) to authenticated;

-- ────────────────────────────────────────────────────────────────────────
-- sessions / exercises / sets
-- ────────────────────────────────────────────────────────────────────────

create table if not exists public.sessions (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.profiles on delete cascade,
  partner_id        uuid references public.profiles,
  title             text not null,
  started_at        timestamptz not null,
  duration_seconds  int not null,
  created_at        timestamptz not null default now()
);

create index if not exists sessions_user_idx    on public.sessions (user_id, started_at desc);
create index if not exists sessions_partner_idx on public.sessions (partner_id, started_at desc);

create table if not exists public.exercises (
  id            uuid primary key default gen_random_uuid(),
  session_id    uuid not null references public.sessions on delete cascade,
  catalog_id    text not null,
  name          text not null,
  is_pr         boolean not null default false,
  order_index   int not null
);

create index if not exists exercises_session_idx on public.exercises (session_id, order_index);

create table if not exists public.sets (
  id           uuid primary key default gen_random_uuid(),
  exercise_id  uuid not null references public.exercises on delete cascade,
  set_index    int not null,
  reps         int not null,
  weight       int not null,
  skipped      boolean not null default false
);

create index if not exists sets_exercise_idx on public.sets (exercise_id, set_index);

alter table public.sessions  enable row level security;
alter table public.exercises enable row level security;
alter table public.sets      enable row level security;

drop policy if exists "sessions: read own/partner"  on public.sessions;
drop policy if exists "sessions: write own"         on public.sessions;
drop policy if exists "sessions: delete own"        on public.sessions;
drop policy if exists "sessions: update own"        on public.sessions;

create policy "sessions: read own/partner"
  on public.sessions for select
  using (
    user_id = auth.uid() or
    exists (
      select 1 from public.partnerships p
      where (p.user_a = auth.uid() and p.user_b = sessions.user_id)
         or (p.user_b = auth.uid() and p.user_a = sessions.user_id)
    )
  );

create policy "sessions: write own"
  on public.sessions for insert
  with check (user_id = auth.uid());

create policy "sessions: update own"
  on public.sessions for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "sessions: delete own"
  on public.sessions for delete
  using (user_id = auth.uid());

drop policy if exists "exercises: read via session" on public.exercises;
drop policy if exists "exercises: write via session" on public.exercises;
drop policy if exists "exercises: update via session" on public.exercises;
drop policy if exists "exercises: delete via session" on public.exercises;

create policy "exercises: read via session"
  on public.exercises for select
  using (
    exists (
      select 1 from public.sessions s
      where s.id = exercises.session_id
        and (
          s.user_id = auth.uid() or
          exists (
            select 1 from public.partnerships p
            where (p.user_a = auth.uid() and p.user_b = s.user_id)
               or (p.user_b = auth.uid() and p.user_a = s.user_id)
          )
        )
    )
  );

create policy "exercises: write via session"
  on public.exercises for insert
  with check (
    exists (select 1 from public.sessions s where s.id = exercises.session_id and s.user_id = auth.uid())
  );

create policy "exercises: update via session"
  on public.exercises for update
  using (
    exists (select 1 from public.sessions s where s.id = exercises.session_id and s.user_id = auth.uid())
  );

create policy "exercises: delete via session"
  on public.exercises for delete
  using (
    exists (select 1 from public.sessions s where s.id = exercises.session_id and s.user_id = auth.uid())
  );

drop policy if exists "sets: read via exercise" on public.sets;
drop policy if exists "sets: write via exercise" on public.sets;
drop policy if exists "sets: update via exercise" on public.sets;
drop policy if exists "sets: delete via exercise" on public.sets;

create policy "sets: read via exercise"
  on public.sets for select
  using (
    exists (
      select 1 from public.exercises e
      join public.sessions s on s.id = e.session_id
      where e.id = sets.exercise_id
        and (
          s.user_id = auth.uid() or
          exists (
            select 1 from public.partnerships p
            where (p.user_a = auth.uid() and p.user_b = s.user_id)
               or (p.user_b = auth.uid() and p.user_a = s.user_id)
          )
        )
    )
  );

create policy "sets: write via exercise"
  on public.sets for insert
  with check (
    exists (
      select 1 from public.exercises e
      join public.sessions s on s.id = e.session_id
      where e.id = sets.exercise_id and s.user_id = auth.uid()
    )
  );

create policy "sets: update via exercise"
  on public.sets for update
  using (
    exists (
      select 1 from public.exercises e
      join public.sessions s on s.id = e.session_id
      where e.id = sets.exercise_id and s.user_id = auth.uid()
    )
  );

create policy "sets: delete via exercise"
  on public.sets for delete
  using (
    exists (
      select 1 from public.exercises e
      join public.sessions s on s.id = e.session_id
      where e.id = sets.exercise_id and s.user_id = auth.uid()
    )
  );

-- ────────────────────────────────────────────────────────────────────────
-- live_sessions
-- ────────────────────────────────────────────────────────────────────────

create table if not exists public.live_sessions (
  user_id                uuid primary key references public.profiles on delete cascade,
  partner_id             uuid references public.profiles,
  started_at             timestamptz not null default now(),
  progress_pct           int not null default 0 check (progress_pct between 0 and 100),
  current_exercise_name  text,
  current_set            int,
  total_sets             int,
  updated_at             timestamptz not null default now()
);

drop trigger if exists live_sessions_set_updated_at on public.live_sessions;
create trigger live_sessions_set_updated_at
  before update on public.live_sessions
  for each row execute procedure public.tg_set_updated_at();

alter table public.live_sessions enable row level security;

drop policy if exists "live: read own/partner"  on public.live_sessions;
drop policy if exists "live: write own"         on public.live_sessions;
drop policy if exists "live: update own"        on public.live_sessions;
drop policy if exists "live: delete own"        on public.live_sessions;

create policy "live: read own/partner"
  on public.live_sessions for select
  using (
    user_id = auth.uid() or
    exists (
      select 1 from public.partnerships p
      where (p.user_a = auth.uid() and p.user_b = live_sessions.user_id)
         or (p.user_b = auth.uid() and p.user_a = live_sessions.user_id)
    )
  );

create policy "live: write own"
  on public.live_sessions for insert
  with check (user_id = auth.uid());

create policy "live: update own"
  on public.live_sessions for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "live: delete own"
  on public.live_sessions for delete
  using (user_id = auth.uid());

alter publication supabase_realtime add table public.live_sessions;

-- ────────────────────────────────────────────────────────────────────────
-- helpful view: partner of the current user
-- ────────────────────────────────────────────────────────────────────────

create or replace view public.my_partner as
  select p.* from public.profiles p
  join public.partnerships pa
    on (pa.user_a = auth.uid() and pa.user_b = p.id)
    or (pa.user_b = auth.uid() and pa.user_a = p.id);

grant select on public.my_partner to authenticated;
