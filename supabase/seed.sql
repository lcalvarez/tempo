-- Seed data for local development only.
--
-- Loaded automatically by `supabase db reset`. Never runs against cloud.
--
-- Creates two demo users (you + Andrea), pairs them, and gives "you" a small
-- history so the app has something to render on first launch.
--
-- Don't put production data in here — it gets nuked on every reset.

-- ────────────────────────────────────────────────────────────────────────
-- demo users
-- ────────────────────────────────────────────────────────────────────────

-- Pre-baked UUIDs so we can reference them across statements.
do $$
declare
  uid_you    constant uuid := '00000000-0000-0000-0000-000000000001';
  uid_andrea constant uuid := '00000000-0000-0000-0000-000000000002';
  sess_id    uuid;
  ex_id      uuid;
begin
  -- Insert into auth.users via the helper Supabase exposes locally. The
  -- handle_new_user() trigger will create the matching profiles row.
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values
    (uid_you,    '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'you@tempo.dev',    crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
    (uid_andrea, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'andrea@tempo.dev', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now())
  on conflict (id) do nothing;

  -- Flesh out profiles (the trigger created stubs already).
  update public.profiles
     set name = 'You', age = 28, fitness_level = 'strong',
         has_onboarded = true, monogram_tone = 'you'
   where id = uid_you;

  update public.profiles
     set name = 'Andrea', age = 26, fitness_level = 'some',
         has_onboarded = true, monogram_tone = 'partner'
   where id = uid_andrea;

  -- Pair them (canonical ordering: smaller UUID first).
  insert into public.partnerships (user_a, user_b)
       values (uid_you, uid_andrea)
  on conflict do nothing;

  -- ──────────────────────────────────────────────────────────────────
  -- a sample completed session in 'You's history (lower-body day)
  -- ──────────────────────────────────────────────────────────────────

  insert into public.sessions (user_id, partner_id, title, started_at, duration_seconds)
       values (uid_you, uid_andrea, 'Lower body & core', now() - interval '2 days', 47 * 60)
    returning id into sess_id;

  insert into public.exercises (session_id, catalog_id, name, is_pr, order_index)
       values (sess_id, 'back_squat', 'Back squat', true, 0)
    returning id into ex_id;
  insert into public.sets (exercise_id, set_index, reps, weight) values
    (ex_id, 0, 6, 195),
    (ex_id, 1, 6, 195),
    (ex_id, 2, 6, 200),
    (ex_id, 3, 5, 200);

  insert into public.exercises (session_id, catalog_id, name, is_pr, order_index)
       values (sess_id, 'romanian_dl', 'Romanian deadlift', false, 1)
    returning id into ex_id;
  insert into public.sets (exercise_id, set_index, reps, weight) values
    (ex_id, 0, 8, 155),
    (ex_id, 1, 8, 155),
    (ex_id, 2, 8, 155);

  insert into public.exercises (session_id, catalog_id, name, is_pr, order_index)
       values (sess_id, 'walking_lunge', 'Walking lunge', false, 2)
    returning id into ex_id;
  insert into public.sets (exercise_id, set_index, reps, weight) values
    (ex_id, 0, 20, 0),
    (ex_id, 1, 20, 0),
    (ex_id, 2, 20, 0);

  -- ──────────────────────────────────────────────────────────────────
  -- a second session (upper-body)
  -- ──────────────────────────────────────────────────────────────────

  insert into public.sessions (user_id, partner_id, title, started_at, duration_seconds)
       values (uid_you, uid_andrea, 'Push day', now() - interval '4 days', 52 * 60)
    returning id into sess_id;

  insert into public.exercises (session_id, catalog_id, name, is_pr, order_index)
       values (sess_id, 'bench_press', 'Bench press', false, 0)
    returning id into ex_id;
  insert into public.sets (exercise_id, set_index, reps, weight) values
    (ex_id, 0, 5, 165),
    (ex_id, 1, 5, 165),
    (ex_id, 2, 5, 165),
    (ex_id, 3, 4, 165);

  insert into public.exercises (session_id, catalog_id, name, is_pr, order_index)
       values (sess_id, 'overhead_press', 'Overhead press', true, 1)
    returning id into ex_id;
  insert into public.sets (exercise_id, set_index, reps, weight) values
    (ex_id, 0, 6, 85),
    (ex_id, 1, 6, 85),
    (ex_id, 2, 5, 85);
end $$;
