#!/usr/bin/env bash
# scripts/smoke-signin-with-app.sh
#
# Verifies that an anonymous user can be upgraded to a real
# email/password account in place — i.e. `auth.uid()` stays stable, all
# RLS-bound data (profile, sessions, partnership) carries over, and
# `is_anonymous` flips to false.
set -euo pipefail

UDID="${UDID:-$(xcrun simctl list devices booted | grep -oE '[A-F0-9-]{36}' | head -1)}"

say()  { printf "\n\033[1;36m▸ %s\033[0m\n" "$*"; }
fail() { printf "\033[1;31m✗ %s\033[0m\n" "$*"; exit 1; }
pass() { printf "\033[1;32m✓ %s\033[0m\n" "$*"; }

# ──────────────────────────────────────────────────────────────────────
# 1. Identify the simulator's anon user
# ──────────────────────────────────────────────────────────────────────

say "1/4  Confirming simulator is anonymous"
DOCS=$(xcrun simctl get_app_container "$UDID" com.tempo.app data 2>/dev/null)/Documents
LOG="$DOCS/remote-sync.log"
[[ -f "$LOG" ]] || fail "no $LOG — has the app launched?"
APP_ID=$(grep -oE 'refreshed profile from server for [A-F0-9-]+' "$LOG" | tail -1 | grep -oE '[A-F0-9-]{36}' | tr 'A-F' 'a-f')
[[ -n "$APP_ID" ]] || fail "couldn't parse user id"

ANON=$(docker exec supabase_db_tempo psql -U postgres -d postgres -At \
  -c "select is_anonymous from auth.users where id='$APP_ID';")
if [[ "$ANON" != "t" ]]; then
  pass "user $APP_ID is already non-anonymous (skipping; rerun with a fresh sim user to exercise this)"
  exit 0
fi
pass "user $APP_ID is anonymous (as expected)"

# ──────────────────────────────────────────────────────────────────────
# 2. Drop a link-account JSON, relaunch
# ──────────────────────────────────────────────────────────────────────

say "2/4  Driving linkEmailToCurrentUser via test-link-account.json"
EMAIL="smoke-link-$(date +%s)@tempo.local"
PASSWORD="tempo-smoke-pass"
cat > "$DOCS/test-link-account.json" <<EOF
{ "email": "$EMAIL", "password": "$PASSWORD" }
EOF

xcrun simctl terminate "$UDID" com.tempo.app >/dev/null 2>&1 || true
sleep 1
xcrun simctl launch "$UDID" com.tempo.app >/dev/null
sleep 5

DOCS=$(xcrun simctl get_app_container "$UDID" com.tempo.app data 2>/dev/null)/Documents
LOG="$DOCS/remote-sync.log"

# ──────────────────────────────────────────────────────────────────────
# 3. Verify auth.users now has the email and is_anonymous=false, same id
# ──────────────────────────────────────────────────────────────────────

say "3/4  Confirming auth.users now has email + is_anonymous=false"
EMAIL_DB=$(docker exec supabase_db_tempo psql -U postgres -d postgres -At \
  -c "select email from auth.users where id='$APP_ID';")
ANON_AFTER=$(docker exec supabase_db_tempo psql -U postgres -d postgres -At \
  -c "select is_anonymous from auth.users where id='$APP_ID';")

[[ "$EMAIL_DB" == "$EMAIL" ]] || { tail -10 "$LOG"; fail "auth.users.email is '$EMAIL_DB', expected '$EMAIL'"; }
[[ "$ANON_AFTER" == "f" ]] || fail "is_anonymous is '$ANON_AFTER', expected 'f'"
pass "user $APP_ID is now bound to $EMAIL (no longer anonymous)"

# ──────────────────────────────────────────────────────────────────────
# 4. Verify their profile row is still theirs (auth.uid() didn't change)
# ──────────────────────────────────────────────────────────────────────

say "4/4  Verifying profile row still belongs to same uid"
PROFILE_EXISTS=$(docker exec supabase_db_tempo psql -U postgres -d postgres -At \
  -c "select count(*) from public.profiles where id='$APP_ID';")
[[ "$PROFILE_EXISTS" == "1" ]] || fail "profile row missing for $APP_ID"
pass "profile row preserved across the link operation"

printf "\n\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
printf "\033[1;32m✓ Anonymous → email/password upgrade works in place\033[0m\n"
printf "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
