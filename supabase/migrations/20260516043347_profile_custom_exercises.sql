-- ────────────────────────────────────────────────────────────────────────
-- profiles.custom_exercises: user-defined exercises live as a jsonb blob
-- ────────────────────────────────────────────────────────────────────────
--
-- v1 stores the user's custom exercises inline on the profile row as
-- jsonb. The shape mirrors the Swift `CustomExercise` struct exactly so
-- the iOS app can encode/decode with the same Codable JSON it already
-- uses locally. We chose jsonb over a dedicated `custom_exercises` table
-- to keep the round-trip simple — these rows are always read alongside
-- the rest of the profile, never joined cross-user, and the volume per
-- user is small (tens, not thousands).
--
-- If we later need server-side filtering ("find all exercises that target
-- the lats" across the catalog + customs of the user + their partner),
-- this is the migration to lift into a proper relational table.

alter table public.profiles
  add column if not exists custom_exercises jsonb not null default '[]'::jsonb;
