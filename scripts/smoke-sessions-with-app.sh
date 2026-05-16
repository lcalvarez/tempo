#!/usr/bin/env bash
# scripts/smoke-sessions-with-app.sh
#
# End-to-end test for the completed-sessions write/read pipeline:
#
#   1. Mint a JWT for the simulator's auth.uid (via service_role admin token).
#   2. Insert a session + 2 exercises + 4 sets via PostgREST as that user.
#   3. Relaunch the app — `RemoteSync.refreshHistory` should pull them down.
#   4. Confirm app log shows "✓ refreshed N sessions" with N >= 1.
#
# Doesn't yet exercise the *write* path (saveCompletedSession from the app
# back up to Supabase) — that requires UI interaction. The
# `pushCompletedSession` hook is verified by code inspection + a unit-style
# test left for the XCTest target work.
set -euo pipefail

UDID="${UDID:-$(xcrun simctl list devices booted | grep -oE '[A-F0-9-]{36}' | head -1)}"
SUPA_URL="${SUPA_URL:-http://127.0.0.1:54321}"
SUPA_ANON="${SUPA_ANON:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0}"
SUPA_SERVICE="${SUPA_SERVICE:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU}"

say()  { printf "\n\033[1;36m▸ %s\033[0m\n" "$*"; }
fail() { printf "\033[1;31m✗ %s\033[0m\n" "$*"; exit 1; }
pass() { printf "\033[1;32m✓ %s\033[0m\n" "$*"; }

# ──────────────────────────────────────────────────────────────────────
# 1. Identify the simulator's user
# ──────────────────────────────────────────────────────────────────────

say "1/6  Reading simulator's user id from app log"
DOCS=$(xcrun simctl get_app_container "$UDID" com.tempo.app data 2>/dev/null)/Documents
LOG="$DOCS/remote-sync.log"
[[ -f "$LOG" ]] || fail "no $LOG — has the app launched?"
APP_ID=$(grep -oE 'refreshed profile from server for [A-F0-9-]+' "$LOG" | tail -1 | grep -oE '[A-F0-9-]{36}' | tr 'A-F' 'a-f')
[[ -n "$APP_ID" ]] || fail "couldn't parse user id from log"
pass "app user_id=$APP_ID"

# ──────────────────────────────────────────────────────────────────────
# 2. Insert a session row via service_role (bypasses RLS)
# ──────────────────────────────────────────────────────────────────────

say "2/6  Injecting a synthetic completed session into DB"
SESSION_ID=$(uuidgen | tr 'A-F' 'a-f')
EX1_ID=$(uuidgen | tr 'A-F' 'a-f')
EX2_ID=$(uuidgen | tr 'A-F' 'a-f')

# Cleanup prior synthetic rows so the test is repeatable.
docker exec supabase_db_tempo psql -U postgres -d postgres -c \
  "delete from public.sessions where title like 'Smoke Session%';" >/dev/null

curl -s -X POST "$SUPA_URL/rest/v1/sessions" \
  -H "apikey: $SUPA_SERVICE" -H "Authorization: Bearer $SUPA_SERVICE" \
  -H "Content-Type: application/json" -H "Prefer: return=minimal" \
  -d "{
    \"id\":\"$SESSION_ID\",
    \"user_id\":\"$APP_ID\",
    \"title\":\"Smoke Session\",
    \"started_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"duration_seconds\":2700
  }" >/dev/null

curl -s -X POST "$SUPA_URL/rest/v1/exercises" \
  -H "apikey: $SUPA_SERVICE" -H "Authorization: Bearer $SUPA_SERVICE" \
  -H "Content-Type: application/json" -H "Prefer: return=minimal" \
  -d "[
    {\"id\":\"$EX1_ID\",\"session_id\":\"$SESSION_ID\",\"catalog_id\":\"squat\",\"name\":\"Back squat\",\"is_pr\":true,\"order_index\":0},
    {\"id\":\"$EX2_ID\",\"session_id\":\"$SESSION_ID\",\"catalog_id\":\"bench\",\"name\":\"Bench press\",\"is_pr\":false,\"order_index\":1}
  ]" >/dev/null

curl -s -X POST "$SUPA_URL/rest/v1/sets" \
  -H "apikey: $SUPA_SERVICE" -H "Authorization: Bearer $SUPA_SERVICE" \
  -H "Content-Type: application/json" -H "Prefer: return=minimal" \
  -d "[
    {\"exercise_id\":\"$EX1_ID\",\"set_index\":0,\"reps\":5,\"weight\":225,\"skipped\":false},
    {\"exercise_id\":\"$EX1_ID\",\"set_index\":1,\"reps\":5,\"weight\":235,\"skipped\":false},
    {\"exercise_id\":\"$EX2_ID\",\"set_index\":0,\"reps\":8,\"weight\":135,\"skipped\":false},
    {\"exercise_id\":\"$EX2_ID\",\"set_index\":1,\"reps\":8,\"weight\":145,\"skipped\":false}
  ]" >/dev/null

ROWS=$(docker exec supabase_db_tempo psql -U postgres -d postgres -At \
  -c "select count(*) from public.sessions where id='$SESSION_ID';")
[[ "$ROWS" == "1" ]] || fail "session insert failed"
pass "session $SESSION_ID + 2 exercises + 4 sets persisted"

# ──────────────────────────────────────────────────────────────────────
# 3. Relaunch app so the launch task runs `refreshHistory`
# ──────────────────────────────────────────────────────────────────────

say "3/6  Relaunching app to trigger refreshHistory"
xcrun simctl terminate "$UDID" com.tempo.app >/dev/null 2>&1 || true
sleep 1
xcrun simctl launch "$UDID" com.tempo.app >/dev/null
sleep 5

# After relaunch the sandbox path may have changed (new Application UUID).
DOCS=$(xcrun simctl get_app_container "$UDID" com.tempo.app data 2>/dev/null)/Documents
LOG="$DOCS/remote-sync.log"

# ──────────────────────────────────────────────────────────────────────
# 4. Verify the app pulled the session down
# ──────────────────────────────────────────────────────────────────────

say "4/6  Inspecting app log for refresh"
COUNT=$(grep -oE '✓ refreshed [0-9]+ sessions' "$LOG" | tail -1 | grep -oE '[0-9]+')
if [[ -z "$COUNT" ]]; then
  echo "----- $LOG (last 20) -----"
  tail -20 "$LOG"
  fail "no '✓ refreshed N sessions' log line"
fi
[[ "$COUNT" -ge 1 ]] || fail "app refreshed $COUNT sessions, expected ≥ 1"
pass "app refreshed $COUNT session(s) from server"

# ──────────────────────────────────────────────────────────────────────
# 5. Write path: drop a JSON session, app pushes it to Supabase
# ──────────────────────────────────────────────────────────────────────

say "5/6  Driving saveCompletedSession via test-save-session.json"
WRITE_SESSION_ID=$(uuidgen | tr 'A-F' 'a-f')
WRITE_EX_ID=$(uuidgen | tr 'A-F' 'a-f')
WRITE_SET_ID=$(uuidgen | tr 'A-F' 'a-f')
ISO_NOW=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)

cat > "$DOCS/test-save-session.json" <<EOF
{
  "id": "$WRITE_SESSION_ID",
  "title": "Smoke Write Session",
  "partnerTitle": "",
  "date": "$ISO_NOW",
  "durationSeconds": 1800,
  "you": [
    {
      "id": "$WRITE_EX_ID",
      "catalogId": "deadlift",
      "name": "Deadlift",
      "isPR": true,
      "sets": [
        {"id": "$WRITE_SET_ID", "reps": 5, "weight": 315, "skipped": false}
      ]
    }
  ],
  "partner": []
}
EOF

xcrun simctl terminate "$UDID" com.tempo.app >/dev/null 2>&1 || true
sleep 1
xcrun simctl launch "$UDID" com.tempo.app >/dev/null
sleep 5

DOCS=$(xcrun simctl get_app_container "$UDID" com.tempo.app data 2>/dev/null)/Documents
LOG="$DOCS/remote-sync.log"

ROW_COUNT=$(docker exec supabase_db_tempo psql -U postgres -d postgres -At \
  -c "select count(*) from public.sessions where id='$WRITE_SESSION_ID' and user_id='$APP_ID';")
[[ "$ROW_COUNT" == "1" ]] || { echo "----- $LOG (last 15) -----"; tail -15 "$LOG"; fail "session row not in DB (count=$ROW_COUNT)"; }

EX_COUNT=$(docker exec supabase_db_tempo psql -U postgres -d postgres -At \
  -c "select count(*) from public.exercises where session_id='$WRITE_SESSION_ID';")
[[ "$EX_COUNT" == "1" ]] || fail "expected 1 exercise, got $EX_COUNT"

SET_COUNT=$(docker exec supabase_db_tempo psql -U postgres -d postgres -At \
  -c "select count(*) from public.sets s join public.exercises e on e.id=s.exercise_id where e.session_id='$WRITE_SESSION_ID';")
[[ "$SET_COUNT" == "1" ]] || fail "expected 1 set, got $SET_COUNT"
pass "session+exercise+set written through app code"

# ──────────────────────────────────────────────────────────────────────
# 6. App log shows the push happened
# ──────────────────────────────────────────────────────────────────────

say "6/6  Verifying app logged the push"
if grep -q "✓ saved session" "$LOG"; then
  pass "app log shows '✓ saved session'"
else
  echo "----- $LOG (last 15) -----"
  tail -15 "$LOG"
  fail "expected log line not found"
fi

printf "\n\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
printf "\033[1;32m✓ Sessions read+write pipeline works end to end\033[0m\n"
printf "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
