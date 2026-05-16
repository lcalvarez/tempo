#!/usr/bin/env bash
# scripts/smoke-unpair-cross-device.sh
#
# Verifies the *cross-device* unpair signal: the *other* partner deletes
# the partnerships row, and our running simulator app reacts INSTANTLY
# via the partnership-watch realtime channel — no relaunch, no manual
# refresh.
#
#   1. Resolve the simulator's auth user.
#   2. Make sure a partnership exists (create one if not).
#   3. As service_role (simulating the partner's device), DELETE the
#      partnerships row directly.
#   4. Wait for the simulator app's RemoteSync to log
#      `partnership-watch delete: <id> — flipping to solo`.
#   5. Verify the row is gone server-side.
#
# This catches regressions in:
#   - the realtime publication (`alter publication ... add table partnerships`)
#   - REPLICA IDENTITY FULL (so DELETE payload includes the row id)
#   - RLS scoping (only our partnership rows reach this user's channel)
#   - the Swift handler in `RemoteSync.handlePartnershipDelete`
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

# Service role for the cross-device write (we're acting as the *other*
# user's device, so we need a JWT they could plausibly use).
SERVICE_ROLE="${SUPABASE_SERVICE_ROLE:-$(supabase status -o env 2>/dev/null | awk -F'=' '/^SERVICE_ROLE_KEY=/ {gsub(/"/,"",$2); print $2}')}"
[[ -n "$SERVICE_ROLE" ]] || fail "could not resolve service_role key (set SUPABASE_SERVICE_ROLE)"

# ──────────────────────────────────────────────────────────────────────
# 1. Identify simulator user + partnership
# ──────────────────────────────────────────────────────────────────────

say "1/4  Resolving simulator user + partnership"
APP_ID=$(grep -oE 'refreshed profile from server for [A-F0-9-]+' "$LOG" | tail -1 | grep -oE '[A-F0-9-]{36}' | tr 'A-F' 'a-f')
[[ -n "$APP_ID" ]] || fail "couldn't parse simulator user_id from log"

PARTNERSHIP_ID=$(docker exec supabase_db_tempo psql -U postgres -d postgres -At \
  -c "select id from public.partnerships where user_a='$APP_ID' or user_b='$APP_ID' limit 1;")

# ──────────────────────────────────────────────────────────────────────
# 2. Ensure a partnership exists. If not, create one through the app.
# ──────────────────────────────────────────────────────────────────────

if [[ -z "$PARTNERSHIP_ID" ]]; then
  say "no existing partnership — creating one to unpair from the other side"
  PARTNER_RAW=$(curl -s -X POST "$SUPA_URL/auth/v1/signup" -H "apikey: $SUPA_ANON" -H "Content-Type: application/json" -d '{}')
  PARTNER_TOKEN=$(echo "$PARTNER_RAW" | jget '["access_token"]')
  PARTNER_ID=$(echo "$PARTNER_RAW"    | jget '["user"]["id"]')
  [[ -n "$PARTNER_TOKEN" ]] || { echo "$PARTNER_RAW"; fail "partner signup failed"; }
  curl -s -X PATCH "$SUPA_URL/rest/v1/profiles?id=eq.$PARTNER_ID" \
    -H "apikey: $SUPA_ANON" -H "Authorization: Bearer $PARTNER_TOKEN" \
    -H "Content-Type: application/json" -H "Prefer: return=minimal" \
    -d '{"name":"Cross-device Smoke","fitness_level":"strong","intensity":"hard"}' >/dev/null
  INVITE=$(curl -s -X POST "$SUPA_URL/rest/v1/rpc/create_pair_invite" \
    -H "apikey: $SUPA_ANON" -H "Authorization: Bearer $PARTNER_TOKEN" \
    -H "Content-Type: application/json" -H "Accept: application/vnd.pgrst.object+json" \
    -d '{}')
  TOKEN=$(echo "$INVITE" | jget '["token"]')
  [[ -n "$TOKEN" ]] || { echo "$INVITE"; fail "invite failed"; }
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
pass "partnership $PARTNERSHIP_ID exists; partner about to delete it from their side"

# Sanity: the simulator app should have logged a partnership-watch
# subscribe line at launch / refreshAll.
for _ in $(seq 1 10); do
  if grep -qi "partnership-watch subscribe" "$LOG"; then break; fi
  sleep 1
done
if ! grep -qi "partnership-watch subscribe" "$LOG"; then
  echo "----- $LOG (last 20) -----"; tail -20 "$LOG"
  fail "app never subscribed to partnership-watch"
fi

# ──────────────────────────────────────────────────────────────────────
# 3. Delete the partnership row directly (no relaunch, no app interaction).
# ──────────────────────────────────────────────────────────────────────

# Snapshot the current log size so we can tail only what comes after the
# delete. Without this we'd false-pass on a stale log entry from a
# previous local-side unpair smoke.
say "2/4  Marking log cursor + deleting partnership as the other side"
BEFORE_LINES=$(wc -l < "$LOG")
curl -fsS -X DELETE "$SUPA_URL/rest/v1/partnerships?id=eq.$PARTNERSHIP_ID" \
  -H "apikey: $SERVICE_ROLE" -H "Authorization: Bearer $SERVICE_ROLE" \
  -H "Prefer: return=minimal" >/dev/null
pass "DELETE issued for partnership $PARTNERSHIP_ID"

# ──────────────────────────────────────────────────────────────────────
# 4. Wait for the realtime delete to land in the simulator app.
# ──────────────────────────────────────────────────────────────────────

say "3/4  Waiting for partnership-watch delete to flip the app to solo"
ok=0
expected="partnership-watch delete: $PARTNERSHIP_ID"
for _ in $(seq 1 15); do
  # Look only at lines added since we issued the delete to avoid
  # matching an older `partnership-watch delete:` from a previous run.
  if tail -n "+$((BEFORE_LINES + 1))" "$LOG" | grep -qi "$expected"; then
    ok=1; break
  fi
  sleep 1
done
if [[ "$ok" != "1" ]]; then
  echo "----- $LOG (last 40) -----"; tail -40 "$LOG"
  fail "app never received realtime delete for partnership $PARTNERSHIP_ID"
fi
pass "app log shows '$expected' (no relaunch needed)"

# ──────────────────────────────────────────────────────────────────────
# 5. Verify the row is actually gone.
# ──────────────────────────────────────────────────────────────────────

say "4/4  Confirming partnership row deleted server-side"
STILL=$(docker exec supabase_db_tempo psql -U postgres -d postgres -At \
  -c "select count(*) from public.partnerships where id='$PARTNERSHIP_ID';")
[[ "$STILL" == "0" ]] || fail "partnership $PARTNERSHIP_ID still in DB"
pass "partnership row $PARTNERSHIP_ID is gone"

printf "\n\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
printf "\033[1;32m✓ Cross-device unpair propagates to the running app instantly\033[0m\n"
printf "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
