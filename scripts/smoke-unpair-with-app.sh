#!/usr/bin/env bash
# scripts/smoke-unpair-with-app.sh
#
# Drives the unpair flow end-to-end against the running iOS Simulator:
#   1. Resolve the simulator's auth user from remote-sync.log.
#   2. Make sure a partnership exists. If one doesn't, create one the
#      same way `smoke-pairing-with-app.sh` does (anon partner + invite
#      + drain `test-pair-token.txt`).
#   3. Drop `Documents/test-unpair.txt` and relaunch. The DEBUG drain
#      helper picks it up and calls `session.unpair()`.
#   4. Verify the partnerships row is gone from Postgres.
#   5. Verify the app log shows the success path
#      (`✓ deleted partnership <id>`).
#
# Run after `./ios/run.sh` brings the simulator up. Composable with the
# pairing smoke — if a partnership already exists this script reuses it.
set -euo pipefail

UDID="${UDID:-$(xcrun simctl list devices booted | grep -oE '[A-F0-9-]{36}' | head -1)}"
[[ -n "$UDID" ]] || { echo "no booted simulator"; exit 1; }

SUPA_URL="${SUPA_URL:-http://127.0.0.1:54321}"
SUPA_ANON="${SUPA_ANON:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0}"

say()  { printf "\n\033[1;36m▸ %s\033[0m\n" "$*"; }
fail() { printf "\033[1;31m✗ %s\033[0m\n" "$*"; exit 1; }
pass() { printf "\033[1;32m✓ %s\033[0m\n" "$*"; }
jget() { python3 -c "import sys,json;print(json.load(sys.stdin)$1)"; }

DOCS=$(xcrun simctl get_app_container "$UDID" com.tempo.app data 2>/dev/null)/Documents
LOG="$DOCS/remote-sync.log"
[[ -f "$LOG" ]] || fail "no $LOG — run ios/run.sh first"

# ──────────────────────────────────────────────────────────────────────
# 1. Resolve simulator user
# ──────────────────────────────────────────────────────────────────────

say "1/4  Resolving simulator user + partnership"
APP_ID=$(grep -oE 'refreshed profile from server for [A-F0-9-]+' "$LOG" | tail -1 | grep -oE '[A-F0-9-]{36}' | tr 'A-F' 'a-f')
[[ -n "$APP_ID" ]] || fail "couldn't parse simulator user_id from log"

PARTNERSHIP_ID=$(docker exec supabase_db_tempo psql -U postgres -d postgres -At \
  -c "select id from public.partnerships where user_a='$APP_ID' or user_b='$APP_ID' limit 1;")

# ──────────────────────────────────────────────────────────────────────
# 2. Ensure a partnership exists (create one if not)
# ──────────────────────────────────────────────────────────────────────

if [[ -z "$PARTNERSHIP_ID" ]]; then
  say "no existing partnership — creating one to unpair from"
  PARTNER_RAW=$(curl -s -X POST "$SUPA_URL/auth/v1/signup" -H "apikey: $SUPA_ANON" -H "Content-Type: application/json" -d '{}')
  PARTNER_TOKEN=$(echo "$PARTNER_RAW" | jget '["access_token"]')
  PARTNER_ID=$(echo "$PARTNER_RAW"    | jget '["user"]["id"]')
  [[ -n "$PARTNER_TOKEN" ]] || { echo "$PARTNER_RAW"; fail "partner signup failed"; }
  curl -s -X PATCH "$SUPA_URL/rest/v1/profiles?id=eq.$PARTNER_ID" \
    -H "apikey: $SUPA_ANON" -H "Authorization: Bearer $PARTNER_TOKEN" \
    -H "Content-Type: application/json" -H "Prefer: return=minimal" \
    -d '{"name":"Unpair Smoke Partner","fitness_level":"strong","intensity":"hard"}' >/dev/null
  INVITE=$(curl -s -X POST "$SUPA_URL/rest/v1/rpc/create_pair_invite" \
    -H "apikey: $SUPA_ANON" -H "Authorization: Bearer $PARTNER_TOKEN" \
    -H "Content-Type: application/json" -H "Accept: application/vnd.pgrst.object+json" \
    -d '{}')
  TOKEN=$(echo "$INVITE" | jget '["token"]')
  [[ -n "$TOKEN" ]] || { echo "$INVITE"; fail "invite creation failed"; }
  echo -n "$TOKEN" > "$DOCS/test-pair-token.txt"
  xcrun simctl terminate "$UDID" com.tempo.app >/dev/null 2>&1 || true
  sleep 1
  xcrun simctl launch "$UDID" com.tempo.app >/dev/null
  sleep 5
  DOCS=$(xcrun simctl get_app_container "$UDID" com.tempo.app data 2>/dev/null)/Documents
  LOG="$DOCS/remote-sync.log"
  PARTNERSHIP_ID=$(docker exec supabase_db_tempo psql -U postgres -d postgres -At \
    -c "select id from public.partnerships where user_a='$APP_ID' or user_b='$APP_ID' limit 1;")
  [[ -n "$PARTNERSHIP_ID" ]] || fail "partnership still missing after pairing"
fi
pass "partnership $PARTNERSHIP_ID is in place — about to tear it down"

# ──────────────────────────────────────────────────────────────────────
# 3. Drop test-unpair.txt and relaunch
# ──────────────────────────────────────────────────────────────────────

say "2/4  Driving unpair via test-unpair.txt"
: > "$DOCS/test-unpair.txt"     # presence is the trigger; content unused
xcrun simctl terminate "$UDID" com.tempo.app >/dev/null 2>&1 || true
sleep 1
xcrun simctl launch "$UDID" com.tempo.app >/dev/null
sleep 5
# Sandbox path may have changed (new Application UUID after terminate/launch).
DOCS=$(xcrun simctl get_app_container "$UDID" com.tempo.app data 2>/dev/null)/Documents
LOG="$DOCS/remote-sync.log"

# ──────────────────────────────────────────────────────────────────────
# 4. Verify DB row gone + app logged the success path
# ──────────────────────────────────────────────────────────────────────

say "3/4  Confirming partnerships row deleted server-side"
STILL=$(docker exec supabase_db_tempo psql -U postgres -d postgres -At \
  -c "select count(*) from public.partnerships where id='$PARTNERSHIP_ID';")
[[ "$STILL" == "0" ]] || fail "partnerships row '$PARTNERSHIP_ID' still present (count=$STILL)"
pass "partnerships row $PARTNERSHIP_ID is gone"

# Don't assert "user has zero partnerships" — repeated smoke runs against
# the same simulator user can leave orphaned rows from older partners
# (e.g. from previous `smoke-pairing-with-app.sh` invocations). What we
# care about is that *the row we just unpaired from* is gone.

say "4/4  Inspecting app log for the unpair path"
ok=0
for _ in $(seq 1 10); do
  if grep -q "test-unpair succeeded" "$LOG" && grep -q "✓ deleted partnership" "$LOG"; then
    ok=1; break
  fi
  sleep 1
done
if [[ "$ok" != "1" ]]; then
  echo "----- $LOG (last 30) -----"; tail -30 "$LOG"
  fail "expected log lines not found"
fi
pass "app log shows '✓ deleted partnership' + 'test-unpair succeeded'"

printf "\n\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
printf "\033[1;32m✓ App-driven unpair pipeline works end to end\033[0m\n"
printf "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
