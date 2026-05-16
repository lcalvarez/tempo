#!/usr/bin/env bash
# scripts/smoke-live-with-app.sh
#
# Verifies the realtime "partner activity" round-trip:
#   1. Find or create a partnership between the running simulator user
#      and a fresh anonymous "partner" identity.
#   2. As the partner, upsert a row into `public.live_sessions`.
#   3. Wait for the simulator app's RemoteSync to receive the realtime
#      delta and log "live partner update: …".
#   4. As the partner, delete the row.
#   5. Wait for the simulator app to log "live delete from <id> — partner
#      finished" and the local `partnerActivity` to clear.
#
# This proves the wire-up: live_sessions table → realtime publication →
# RealtimeChannelV2 → RemoteSync.handleLiveAction → SessionStore.partnerActivity.
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
[[ -f "$LOG" ]] || fail "no $LOG — has the app launched? run ios/run.sh first"

# ──────────────────────────────────────────────────────────────────────
# 1. Identify simulator user + partner. Reuse an existing partnership
#    if one exists (so this script is composable with the pairing one);
#    otherwise create both sides from scratch.
# ──────────────────────────────────────────────────────────────────────

say "1/5  Resolving simulator user + partner"
APP_ID=$(grep -oE 'refreshed profile from server for [A-F0-9-]+' "$LOG" | tail -1 | grep -oE '[A-F0-9-]{36}' | tr 'A-F' 'a-f')
[[ -n "$APP_ID" ]] || fail "couldn't parse simulator user_id from log"

# Existing partnership?
EXISTING=$(docker exec supabase_db_tempo psql -U postgres -d postgres -At \
  -c "select case when user_a='$APP_ID' then user_b else user_a end
        from public.partnerships
       where user_a='$APP_ID' or user_b='$APP_ID' limit 1;")

if [[ -n "$EXISTING" ]]; then
  PARTNER_ID="$EXISTING"
  pass "reusing existing partnership: app=$APP_ID partner=$PARTNER_ID"

  # We need a JWT for the partner to write `live_sessions` as them.
  # We're already past the original anonymous signup so there's no
  # persisted access_token to reuse. Easiest path: use the local
  # service_role key (which bypasses RLS) and pass `user_id=PARTNER_ID`
  # explicitly in the insert. Equivalent to the partner running the
  # write — the schema constraint we care about (the realtime channel
  # filter) is on `user_id`, which we set correctly.
  PARTNER_TOKEN="${SUPABASE_SERVICE_ROLE:-$(supabase status -o env 2>/dev/null | awk -F'=' '/^SERVICE_ROLE_KEY=/ {gsub(/"/,"",$2); print $2}')}"
  [[ -n "$PARTNER_TOKEN" ]] || fail "could not resolve service_role key (set SUPABASE_SERVICE_ROLE or check 'supabase status -o env')"
  USE_SERVICE_ROLE=1
else
  # Fresh partner: anonymous signup → patch profile → create + accept invite
  # via the app's debug drain hook. This branch mirrors smoke-pairing-with-app.sh.
  say "no existing partnership — creating one from scratch"
  PARTNER_RAW=$(curl -s -X POST "$SUPA_URL/auth/v1/signup" -H "apikey: $SUPA_ANON" -H "Content-Type: application/json" -d '{}')
  PARTNER_TOKEN=$(echo "$PARTNER_RAW" | jget '["access_token"]')
  PARTNER_ID=$(echo "$PARTNER_RAW"    | jget '["user"]["id"]')
  [[ -n "$PARTNER_TOKEN" ]] || { echo "$PARTNER_RAW"; fail "partner signup failed"; }
  curl -s -X PATCH "$SUPA_URL/rest/v1/profiles?id=eq.$PARTNER_ID" \
    -H "apikey: $SUPA_ANON" -H "Authorization: Bearer $PARTNER_TOKEN" \
    -H "Content-Type: application/json" -H "Prefer: return=minimal" \
    -d '{"name":"Smoke Partner","fitness_level":"strong","intensity":"hard"}' >/dev/null

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
  pass "partnership created via app: app=$APP_ID partner=$PARTNER_ID"
  USE_SERVICE_ROLE=0
fi

# Sanity: the simulator app should have logged a live subscribe(<partner>) line
# either at app launch or right after partnering.
say "2/5  Confirming app subscribed to partner's live channel"
for _ in $(seq 1 10); do
  if grep -qi "live subscribe" "$LOG"; then break; fi
  sleep 1
done
if ! grep -qi "live subscribe" "$LOG"; then
  echo "----- $LOG (last 20) -----"; tail -20 "$LOG"
  fail "app never subscribed to a live channel"
fi
pass "app subscribed to a live channel"

# ──────────────────────────────────────────────────────────────────────
# 3. Insert/upsert a live_sessions row as the partner
# ──────────────────────────────────────────────────────────────────────

say "3/5  Partner upserts a live_sessions row"
NOW_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
PAYLOAD=$(cat <<EOF
{
  "user_id": "$PARTNER_ID",
  "partner_id": "$APP_ID",
  "started_at": "$NOW_ISO",
  "progress_pct": 38,
  "current_exercise_name": "Goblet squat",
  "current_set": 3,
  "total_sets": 8
}
EOF
)

if [[ "$USE_SERVICE_ROLE" == "1" ]]; then
  # service_role bypasses RLS so we can write the row as any user.
  curl -fsS -X POST "$SUPA_URL/rest/v1/live_sessions" \
    -H "apikey: $PARTNER_TOKEN" \
    -H "Authorization: Bearer $PARTNER_TOKEN" \
    -H "Content-Type: application/json" \
    -H "Prefer: resolution=merge-duplicates,return=minimal" \
    -d "$PAYLOAD" >/dev/null
else
  curl -fsS -X POST "$SUPA_URL/rest/v1/live_sessions" \
    -H "apikey: $SUPA_ANON" \
    -H "Authorization: Bearer $PARTNER_TOKEN" \
    -H "Content-Type: application/json" \
    -H "Prefer: resolution=merge-duplicates,return=minimal" \
    -d "$PAYLOAD" >/dev/null
fi
pass "row written: $PARTNER_ID @ Goblet squat 3/8 · 38%"

# ──────────────────────────────────────────────────────────────────────
# 4. Wait for app to log the realtime delta
# ──────────────────────────────────────────────────────────────────────

say "4/5  Waiting for realtime delta to land in the app"
ok=0
for _ in $(seq 1 15); do
  if grep -q "live partner update.*Goblet squat" "$LOG"; then
    ok=1; break
  fi
  sleep 1
done
if [[ "$ok" != "1" ]]; then
  echo "----- $LOG (last 30) -----"; tail -30 "$LOG"
  fail "app never received realtime delta for partner activity"
fi
pass "app log shows partner update with 'Goblet squat'"

# ──────────────────────────────────────────────────────────────────────
# 5. Delete the row, expect a "live delete" log line
# ──────────────────────────────────────────────────────────────────────

say "5/5  Partner clears live_sessions; app should drop banner"
if [[ "$USE_SERVICE_ROLE" == "1" ]]; then
  curl -fsS -X DELETE "$SUPA_URL/rest/v1/live_sessions?user_id=eq.$PARTNER_ID" \
    -H "apikey: $PARTNER_TOKEN" -H "Authorization: Bearer $PARTNER_TOKEN" \
    -H "Prefer: return=minimal" >/dev/null
else
  curl -fsS -X DELETE "$SUPA_URL/rest/v1/live_sessions?user_id=eq.$PARTNER_ID" \
    -H "apikey: $SUPA_ANON" -H "Authorization: Bearer $PARTNER_TOKEN" \
    -H "Prefer: return=minimal" >/dev/null
fi

ok=0
for _ in $(seq 1 15); do
  if grep -q "live delete from .* partner finished\|live delete from $PARTNER_ID" "$LOG"; then
    ok=1; break
  fi
  sleep 1
done
if [[ "$ok" != "1" ]]; then
  echo "----- $LOG (last 30) -----"; tail -30 "$LOG"
  fail "app never received realtime delete for partner activity"
fi
pass "app log shows 'live delete from $PARTNER_ID'"

printf "\n\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
printf "\033[1;32m✓ Realtime partner-activity round-trip works end to end\033[0m\n"
printf "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
