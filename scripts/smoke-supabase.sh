#!/usr/bin/env bash
# scripts/smoke-supabase.sh
#
# End-to-end smoke test against the local (or any) Supabase stack. Verifies
# that auth, the `handle_new_user` trigger, RLS policies, and the REST API
# all work as the iOS app expects them to.
#
# Run this BEFORE pushing migrations to your cloud project, and any time you
# change the schema. It will catch entire categories of bugs the Swift type
# checker can't (column names, enum values, missing policies, RLS holes).
#
# Usage:
#   scripts/smoke-supabase.sh                # uses local supabase (default)
#   SUPA_URL=https://xxx.supabase.co \
#   SUPA_ANON=eyJ... scripts/smoke-supabase.sh
set -euo pipefail

# Defaults: local Supabase via `supabase start`. Override via env vars to run
# the same script against your cloud project.
SUPA_URL="${SUPA_URL:-http://127.0.0.1:54321}"
SUPA_ANON="${SUPA_ANON:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0}"

# Random email each run so we don't collide with previous test users.
EMAIL="smoke+$(date +%s)@example.com"
PASS="testpass123!"

say()  { printf "\n\033[1;36m▸ %s\033[0m\n" "$*"; }
fail() { printf "\033[1;31m✗ %s\033[0m\n" "$*"; exit 1; }
pass() { printf "\033[1;32m✓ %s\033[0m\n" "$*"; }

# ─── 1. Sanity check: stack is reachable ──────────────────────────────────
say "1/5  Reaching $SUPA_URL"
HTTP=$(curl -s -o /dev/null -w "%{http_code}" "$SUPA_URL/rest/v1/" -H "apikey: $SUPA_ANON")
[[ "$HTTP" == "200" ]] || fail "REST not reachable (got $HTTP). Did you run 'supabase start'?"
pass "REST API reachable"

# ─── 2. Sign up a fresh user ──────────────────────────────────────────────
say "2/5  Signing up $EMAIL"
SIGNUP=$(curl -s -X POST "$SUPA_URL/auth/v1/signup" \
  -H "apikey: $SUPA_ANON" -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}")
ACCESS=$(echo "$SIGNUP" | python3 -c "import sys,json;print(json.load(sys.stdin).get('access_token',''))")
USER_ID=$(echo "$SIGNUP" | python3 -c "import sys,json;d=json.load(sys.stdin);print((d.get('user') or {}).get('id',''))")
[[ -n "$ACCESS" && -n "$USER_ID" ]] || { echo "$SIGNUP"; fail "signup failed"; }
pass "user_id=$USER_ID"

# ─── 3. Trigger should have auto-created a profile row ────────────────────
say "3/5  Verifying handle_new_user() trigger"
ROWS=$(curl -s "$SUPA_URL/rest/v1/profiles?select=id&id=eq.$USER_ID" \
  -H "apikey: $SUPA_ANON" -H "Authorization: Bearer $ACCESS")
COUNT=$(echo "$ROWS" | python3 -c "import sys,json;print(len(json.load(sys.stdin)))")
[[ "$COUNT" == "1" ]] || fail "expected 1 profile row, got $COUNT (trigger missing?)"
pass "profile row auto-created"

# ─── 4. Update the profile (matches what OnboardingFlow will do) ──────────
say "4/5  Patching profile (mimics onboarding completion)"
PATCH=$(curl -s -X PATCH "$SUPA_URL/rest/v1/profiles?id=eq.$USER_ID" \
  -H "apikey: $SUPA_ANON" -H "Authorization: Bearer $ACCESS" \
  -H "Content-Type: application/json" -H "Prefer: return=representation" \
  -d '{
    "name":"Smoke Test",
    "fitness_level":"strong",
    "intensity":"hard",
    "focuses":["push","pull","legs"],
    "equipment":["barbell","dumbbells"],
    "has_onboarded":true
  }')
NAME=$(echo "$PATCH" | python3 -c "import sys,json;print(json.load(sys.stdin)[0]['name'])")
[[ "$NAME" == "Smoke Test" ]] || { echo "$PATCH"; fail "profile update returned wrong name: $NAME"; }
pass "profile updated and round-tripped"

# ─── 5. RLS sanity: should only see own profile ───────────────────────────
say "5/5  RLS check — should see only my own profile"
ALL=$(curl -s "$SUPA_URL/rest/v1/profiles?select=id" \
  -H "apikey: $SUPA_ANON" -H "Authorization: Bearer $ACCESS")
ALL_COUNT=$(echo "$ALL" | python3 -c "import sys,json;print(len(json.load(sys.stdin)))")
[[ "$ALL_COUNT" == "1" ]] || fail "RLS leak: visible row count is $ALL_COUNT, expected 1"
pass "RLS enforces row ownership"

printf "\n\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
printf "\033[1;32m✓ Supabase backend is healthy at %s\033[0m\n" "$SUPA_URL"
printf "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
