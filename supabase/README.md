# Tempo · Supabase

Everything Tempo needs from a backend lives here. Schema, auth config, seed
data, helper scripts — all checked into git, all applied via the CLI.

## Layout

```
supabase/
├── config.toml          Auth providers, realtime, project settings (committed)
├── migrations/          Timestamped SQL files, applied in order
│   └── ..._initial_schema.sql
├── seed.sql             Demo data for local dev (never runs on cloud)
└── README.md            ← you are here

scripts/
├── bootstrap-supabase.sh    First-time setup (run once per machine)
├── db-reset.sh              Nuke local DB, re-apply migrations + seed
└── db-push.sh               Apply local migrations to cloud
```

Tempo's Swift layer talks to Supabase via the official `supabase-swift` SDK
with the existing `Codable` models (no codegen — we use `convertFromSnakeCase`
to bridge `snake_case` columns to `camelCase` properties).

## First-time setup

```bash
./scripts/bootstrap-supabase.sh
```

That's it. The script will:

1. Install the Supabase CLI via Homebrew if needed.
2. Log you in (browser).
3. Ask if you want local-only, cloud-only, or both (recommended: both).
4. Start the local Docker stack and apply migrations.
5. Link to / create a cloud project and push migrations.
6. Write `ios/Tempo/Supabase/SupabaseConfig.swift` with the URLs + anon keys.

Run again any time you switch machines or rotate keys.

## Day-to-day

```bash
# Edit a migration?
supabase migration new my_change
$EDITOR supabase/migrations/2026*_my_change.sql
./scripts/db-reset.sh           # apply locally, fresh

# Ready to ship?
./scripts/db-push.sh            # apply to cloud
```

Remember to update the Swift models in `ios/Tempo/Models/Models.swift` to
match any new columns — the compiler won't catch drift since we don't
codegen DTOs.

Other useful commands:

| Command | What it does |
|---|---|
| `supabase start` | Start the local stack |
| `supabase stop` | Stop it |
| `supabase status` | Show local URLs + keys |
| `supabase db diff --linked` | What would change if I pushed? |
| `supabase functions serve` | Run edge functions locally (we don't have any yet) |

Local Supabase Studio: <http://127.0.0.1:54323>. Emails (auth confirmations,
magic links) go to <http://127.0.0.1:54324> — Inbucket, a fake SMTP inbox.

## Apple Developer Portal

The one piece the CLI can't automate. Required for shipping to TestFlight,
not for local simulator dev.

1. <https://developer.apple.com/account/resources/identifiers>
2. **Identifiers → +** → App ID with bundle `com.tempo.app`. Enable
   "Sign In with Apple" capability.
3. Build + run; the iOS native `ASAuthorizationAppleIDProvider` flow handles
   the rest. Supabase verifies the identity token using its own JWKS — no
   `.p8` upload needed for the iOS-native flow.

If you ever add a *web* fallback or use Supabase's hosted auth UI, that's
when you'd configure the Services ID + `.p8` key under
`[auth.external.apple]` in `config.toml`.

## Schema

| Table | Owner | Purpose |
|---|---|---|
| `profiles` | self | Identity + goals + planning prefs (1:1 with `auth.users`) |
| `partnerships` | both | Canonical edges between paired users |
| `pair_invites` | self | Short-lived 6-char codes + share-link tokens |
| `sessions` | self | Completed workouts |
| `exercises` | (via session) | Ordered exercises within a session |
| `sets` | (via exercise) | Sets within an exercise |
| `live_sessions` | self | Realtime per-user "I'm in a workout" row |

Every table has RLS. Two helper RPCs handle the partnership flow safely:

- `create_pair_invite()` — generates code + token for the caller
- `accept_pair_invite(code, token)` — seals the partnership

Both are `SECURITY DEFINER` so they bypass RLS to enforce the canonical
ordering constraint.

## What's NOT in here

- **Edge Functions.** The workout planner (`PlanGenerator.swift`) is
  intentionally on-device. No server roundtrip per session.
- **Storage.** No user-uploaded images yet (monogram-only).
- **Vector / embeddings.** No AI search.

Each of these is a one-command add when needed (`supabase functions new`,
add a `[storage.buckets.*]` block, etc.).
