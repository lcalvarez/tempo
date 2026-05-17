# Tempo · Supabase

Everything Tempo needs from a backend lives here. Schema, auth config, seed
data, helper scripts — all checked into git, all applied via the CLI.

## Layout

```
supabase/
├── config.toml          Auth providers, realtime, project settings (committed)
├── migrations/          Timestamped SQL files, applied in order
│   └── ..._initial_schema.sql
├── functions/           Deno Edge Functions (deployed via supabase functions deploy)
│   ├── generate-plan/   Anthropic Sonnet 4.5 paired planner (per-user/day rate-limited)
│   └── delete-user/     Privileged auth.admin.deleteUser for "Delete account"
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

## Edge Functions

| Function        | Purpose                                                                                                       |
|-----------------|---------------------------------------------------------------------------------------------------------------|
| `generate-plan` | Calls Anthropic Sonnet 4.5 to produce a paired session plan. JWT-authenticated. One generation per user/day.  |
| `delete-user`   | Privileged `auth.admin.deleteUser(uid_from_jwt)` for the Profile → "Delete account" path.                     |

Required secrets (set with `supabase secrets set NAME=value`):

```
ANTHROPIC_API_KEY=sk-ant-…
ANTHROPIC_MODEL=claude-sonnet-4-5      # optional; defaults to claude-sonnet-4-5
```

Locally, drop these in `supabase/.env` and run `supabase functions serve`.

The iOS planner walks a tier list at `PlannerService` (in
`ios/Tempo/AI/`):

1. **Apple Foundation Models** — on-device, iOS 26+, Apple Intelligence-capable hardware. Free, private, offline.
2. **Anthropic Sonnet 4.5** — via this `generate-plan` Edge Function. Used when the device can't run tier 1.
3. **Heuristic** (`PlanGenerator` in `Models.swift`) — deterministic, rule-based fallback when both AI tiers fail or AI is disabled in Profile.

Tiers 1 and 2 cache once-per-local-day on-device (`PlannedDayCache`) so a
day's worth of "Regenerate" taps always returns the same plan instantly.
Heuristic results bypass the cache.

## What's NOT in here

- **Storage.** No user-uploaded images yet (monogram + local JPEG only).
- **Vector / embeddings.** No AI search.

Each of these is a one-command add when needed (add a
`[storage.buckets.*]` block, etc.).
