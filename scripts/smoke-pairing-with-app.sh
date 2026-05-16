#!/usr/bin/env bash
# scripts/smoke-pairing-with-app.sh
#
# Drives an end-to-end pairing flow against the running iOS Simulator:
#   1. Pick the simulator's most recent anonymous user as "the app user."
#   2. Create a SECOND anonymous user via curl ("the partner").
#   3. Have the partner create a pair_invite.
#   4. Open `tempo://pair?t=<token>` on the simulator to drive the accept flow.
#   5. Wait for the app's `RemoteSync.refreshPartner` to settle.
#   6. Verify the partnerships row was created and both sides see each other.
#
# Run after `./run.sh` is up. Useful when changing pairing UX, deep-link
# parsing, or partnership RLS policies — proves the round-trip works
# *through the app code*, not just through curl.
set -euo pipefail

UDID="${UDID:-$(xcrun simctl list devices booted | grep -oE '[A-F0-9-]{36}' | head -1)}"
[[ -n "$UDID" ]] || { echo "no booted simulator"; exit 1; }

SUPA_URL="${SUPA_URL:-http://127.0.0.1:54321}"
SUPA_ANON="${SUPA_ANON:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0}"

say()  { printf "\n\033[1;36m▸ %s\033[0m\n" "$*"; }
fail() { printf "\033[1;31m✗ %s\033[0m\n" "$*"; exit 1; }
pass() { printf "\033[1;32m✓ %s\033[0m\n" "$*"; }
jget() { python3 -c "import sys,json;print(json.load(sys.stdin)$1)"; }

# ──────────────────────────────────────────────────────────────────────
# 1. App user — pull from auth.users (most recent anon)
# ──────────────────────────────────────────────────────────────────────

say "1/5  Identifying the simulator's auth user"
DOCS=$(xcrun simctl get_app_container "$UDID" com.tempo.app data 2>/dev/null)/Documents
LOG="$DOCS/remote-sync.log"
[[ -f "$LOG" ]] || fail "no remote-sync.log at $LOG — app hasn't launched yet?"
# Pull the user id from the most recent "✓ refreshed profile" log line.
APP_ID=$(grep -oE 'refreshed profile from server for [A-F0-9-]+' "$LOG" | tail -1 | grep -oE '[A-F0-9-]{36}' | tr 'A-F' 'a-f')
[[ -n "$APP_ID" ]] || fail "couldn't parse app user_id from $LOG"
pass "app user_id=$APP_ID"
echo "    docs=$DOCS"

# ──────────────────────────────────────────────────────────────────────
# 2. Create a second anon user (the partner) and have them open an invite
# ──────────────────────────────────────────────────────────────────────

say "2/5  Creating partner anonymous user + invite"
PARTNER_RAW=$(curl -s -X POST "$SUPA_URL/auth/v1/signup" -H "apikey: $SUPA_ANON" -H "Content-Type: application/json" -d '{}')
PARTNER_TOKEN=$(echo "$PARTNER_RAW" | jget '["access_token"]')
PARTNER_ID=$(echo "$PARTNER_RAW"    | jget '["user"]["id"]')
[[ -n "$PARTNER_TOKEN" ]] || { echo "$PARTNER_RAW"; fail "partner signup failed"; }

# Stamp a name so we can tell partner from app user in the partner row.
curl -s -X PATCH "$SUPA_URL/rest/v1/profiles?id=eq.$PARTNER_ID" \
  -H "apikey: $SUPA_ANON" -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H "Content-Type: application/json" -H "Prefer: return=minimal" \
  -d '{"name":"Smoke Partner","fitness_level":"strong","intensity":"hard"}' >/dev/null

INVITE=$(curl -s -X POST "$SUPA_URL/rest/v1/rpc/create_pair_invite" \
  -H "apikey: $SUPA_ANON" -H "Authorization: Bearer $PARTNER_TOKEN" \
  -H "Content-Type: application/json" -H "Accept: application/vnd.pgrst.object+json" \
  -d '{}')
TOKEN=$(echo "$INVITE" | jget '["token"]')
[[ -n "$TOKEN" ]] || { echo "$INVITE"; fail "invite creation failed"; }
pass "partner=$PARTNER_ID  token=${TOKEN:0:8}…"

# ──────────────────────────────────────────────────────────────────────
# 3. Deep-link the simulator into accept-invite flow
# ──────────────────────────────────────────────────────────────────────

say "3/5  Driving accept-invite via test-pair-token.txt drop"
# `simctl openurl` is unreliable on iOS 26 simulators (system delivers the URL
# to SpringBoard but neither SwiftUI's onOpenURL nor UIKit's
# application(_:open:) fire). The DEBUG build of the app reads a
# `test-pair-token.txt` file from its Documents on launch as a fallback.
echo -n "$TOKEN" > "$DOCS/test-pair-token.txt"
# Force the app to re-run its launch task: terminate + launch.
xcrun simctl terminate "$UDID" com.tempo.app >/dev/null 2>&1 || true
sleep 1
xcrun simctl launch "$UDID" com.tempo.app >/dev/null
pass "token dropped + app relaunched"

# Give RemoteSync time to (a) accept (b) refresh partner.
sleep 5

# ──────────────────────────────────────────────────────────────────────
# 4. Verify the partnership exists server-side
# ──────────────────────────────────────────────────────────────────────

say "4/5  Confirming partnerships row exists"
PARTNERSHIPS=$(docker exec supabase_db_tempo psql -U postgres -d postgres -At \
  -c "select count(*) from public.partnerships where (user_a='$APP_ID' and user_b='$PARTNER_ID') or (user_b='$APP_ID' and user_a='$PARTNER_ID');")
[[ "$PARTNERSHIPS" == "1" ]] || fail "expected 1 partnership row, got '$PARTNERSHIPS'"
pass "partnership row created in DB"

# ──────────────────────────────────────────────────────────────────────
# 5. Inspect the app's log file to confirm RemoteSync ran the right path
# ──────────────────────────────────────────────────────────────────────

say "5/5  Inspecting app log for partner refresh"
# After the relaunch the sandbox path may have changed (new Application UUID).
DOCS=$(xcrun simctl get_app_container "$UDID" com.tempo.app data 2>/dev/null)/Documents
LOG="$DOCS/remote-sync.log"
if [[ ! -f "$LOG" ]]; then
  fail "no remote-sync.log at $LOG"
fi

if grep -q "test-pair-token acceptPartner succeeded" "$LOG" && \
   grep -q "✓ refreshed partner" "$LOG"; then
  pass "app log shows accept + partner refresh"
else
  echo "----- $LOG (last 30 lines) -----"
  tail -30 "$LOG"
  fail "expected log lines not found"
fi

printf "\n\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
printf "\033[1;32m✓ App-driven pairing pipeline works end to end\033[0m\n"
printf "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
