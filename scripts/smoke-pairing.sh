#!/usr/bin/env bash
# scripts/smoke-pairing.sh
#
# End-to-end pairing test: spins up two anonymous users, has User A
# create an invite, has User B accept it, and verifies that both sides
# see each other through the partnerships table + my_partner view + RLS.
#
# Run after `supabase start` is up. Use this whenever the pairing schema
# (partnerships, pair_invites, RPCs, my_partner view) changes.
set -euo pipefail

SUPA_URL="${SUPA_URL:-http://127.0.0.1:54321}"
SUPA_ANON="${SUPA_ANON:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0}"

say()  { printf "\n\033[1;36m▸ %s\033[0m\n" "$*"; }
fail() { printf "\033[1;31m✗ %s\033[0m\n" "$*"; exit 1; }
pass() { printf "\033[1;32m✓ %s\033[0m\n" "$*"; }
jget() { python3 -c "import sys,json;print(json.load(sys.stdin)$1)"; }

# ──────────────────────────────────────────────────────────────────────
# 1. Two anonymous users
# ──────────────────────────────────────────────────────────────────────

say "1/6  Creating two anonymous users (A & B)"

A_RAW=$(curl -s -X POST "$SUPA_URL/auth/v1/signup" -H "apikey: $SUPA_ANON" -H "Content-Type: application/json" -d '{}')
A_TOKEN=$(echo "$A_RAW" | jget '["access_token"]')
A_ID=$(echo "$A_RAW"    | jget '["user"]["id"]')

B_RAW=$(curl -s -X POST "$SUPA_URL/auth/v1/signup" -H "apikey: $SUPA_ANON" -H "Content-Type: application/json" -d '{}')
B_TOKEN=$(echo "$B_RAW" | jget '["access_token"]')
B_ID=$(echo "$B_RAW"    | jget '["user"]["id"]')

[[ -n "$A_TOKEN" && -n "$B_TOKEN" ]] || fail "couldn't sign up two users"
pass "A=$A_ID  B=$B_ID"

# ──────────────────────────────────────────────────────────────────────
# 2. A creates an invite
# ──────────────────────────────────────────────────────────────────────

say "2/6  User A calls create_pair_invite()"
INVITE=$(curl -s -X POST "$SUPA_URL/rest/v1/rpc/create_pair_invite" \
  -H "apikey: $SUPA_ANON" -H "Authorization: Bearer $A_TOKEN" \
  -H "Content-Type: application/json" -H "Accept: application/vnd.pgrst.object+json" \
  -d '{}')
CODE=$(echo "$INVITE"  | jget '["code"]')
TOKEN=$(echo "$INVITE" | jget '["token"]')
[[ -n "$CODE" && ${#CODE} -eq 6 ]] || { echo "$INVITE"; fail "invite missing code"; }
pass "code=$CODE  token=${TOKEN:0:8}…"

# ──────────────────────────────────────────────────────────────────────
# 3. B accepts the invite (via token, the deep-link path)
# ──────────────────────────────────────────────────────────────────────

say "3/6  User B calls accept_pair_invite(p_token=…)"
ACCEPT=$(curl -s -X POST "$SUPA_URL/rest/v1/rpc/accept_pair_invite" \
  -H "apikey: $SUPA_ANON" -H "Authorization: Bearer $B_TOKEN" \
  -H "Content-Type: application/json" -H "Accept: application/vnd.pgrst.object+json" \
  -d "{\"p_token\":\"$TOKEN\"}")
PARTNERSHIP_ID=$(echo "$ACCEPT" | jget '["id"]' 2>/dev/null || echo "")
[[ -n "$PARTNERSHIP_ID" ]] || { echo "$ACCEPT"; fail "accept did not return a partnership"; }
pass "partnership_id=$PARTNERSHIP_ID"

# ──────────────────────────────────────────────────────────────────────
# 4. Both sides should now see the other via my_partner
# ──────────────────────────────────────────────────────────────────────

say "4/6  A queries my_partner — should see B"
A_SEES=$(curl -s "$SUPA_URL/rest/v1/my_partner?select=id" \
  -H "apikey: $SUPA_ANON" -H "Authorization: Bearer $A_TOKEN")
A_ROWS=$(echo "$A_SEES" | python3 -c "import sys,json;print(len(json.load(sys.stdin)))")
[[ "$A_ROWS" == "1" ]] || { echo "$A_SEES"; fail "A should see exactly 1 partner, saw $A_ROWS"; }

B_SEES=$(curl -s "$SUPA_URL/rest/v1/my_partner?select=id" \
  -H "apikey: $SUPA_ANON" -H "Authorization: Bearer $B_TOKEN")
B_ROWS=$(echo "$B_SEES" | python3 -c "import sys,json;print(len(json.load(sys.stdin)))")
[[ "$B_ROWS" == "1" ]] || { echo "$B_SEES"; fail "B should see exactly 1 partner, saw $B_ROWS"; }
pass "both sides see exactly one partner"

# ──────────────────────────────────────────────────────────────────────
# 5. Per-side relationship labels
# ──────────────────────────────────────────────────────────────────────

say "5/6  A sets their label for B → 'wife'; B sets theirs for A → 'husband'"
curl -s -X POST "$SUPA_URL/rest/v1/rpc/set_relationship_label" \
  -H "apikey: $SUPA_ANON" -H "Authorization: Bearer $A_TOKEN" \
  -H "Content-Type: application/json" -H "Accept: application/vnd.pgrst.object+json" \
  -d "{\"p_partnership_id\":\"$PARTNERSHIP_ID\",\"p_label\":\"wife\"}" >/dev/null
curl -s -X POST "$SUPA_URL/rest/v1/rpc/set_relationship_label" \
  -H "apikey: $SUPA_ANON" -H "Authorization: Bearer $B_TOKEN" \
  -H "Content-Type: application/json" -H "Accept: application/vnd.pgrst.object+json" \
  -d "{\"p_partnership_id\":\"$PARTNERSHIP_ID\",\"p_label\":\"husband\"}" >/dev/null

PARTNERSHIP=$(curl -s "$SUPA_URL/rest/v1/partnerships?select=user_a_label,user_b_label,user_a,user_b&id=eq.$PARTNERSHIP_ID" \
  -H "apikey: $SUPA_ANON" -H "Authorization: Bearer $A_TOKEN")
A_LABEL=$(echo "$PARTNERSHIP" | python3 -c "import sys,json;d=json.load(sys.stdin)[0];print(d['user_a_label'] if d['user_a']=='$A_ID' else d['user_b_label'])")
B_LABEL=$(echo "$PARTNERSHIP" | python3 -c "import sys,json;d=json.load(sys.stdin)[0];print(d['user_b_label'] if d['user_b']=='$B_ID' else d['user_a_label'])")
[[ "$A_LABEL" == "wife"    ]] || fail "A's label is '$A_LABEL', expected 'wife'"
[[ "$B_LABEL" == "husband" ]] || fail "B's label is '$B_LABEL', expected 'husband'"
pass "labels A='$A_LABEL', B='$B_LABEL'"

# ──────────────────────────────────────────────────────────────────────
# 6. Replay attack: re-using the same invite must fail
# ──────────────────────────────────────────────────────────────────────

say "6/6  Replaying the same invite should be rejected"
REPLAY=$(curl -s -X POST "$SUPA_URL/rest/v1/rpc/accept_pair_invite" \
  -H "apikey: $SUPA_ANON" -H "Authorization: Bearer $B_TOKEN" \
  -H "Content-Type: application/json" -H "Accept: application/vnd.pgrst.object+json" \
  -d "{\"p_token\":\"$TOKEN\"}")
ERR=$(echo "$REPLAY" | python3 -c "import sys,json;print(json.load(sys.stdin).get('message',''))" 2>/dev/null || echo "")
[[ "$ERR" == *"already accepted"* || "$ERR" == *"not found"* ]] || { echo "$REPLAY"; fail "replay should error, got: $ERR"; }
pass "replay correctly rejected ($ERR)"

printf "\n\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
printf "\033[1;32m✓ Pairing pipeline is healthy at %s\033[0m\n" "$SUPA_URL"
printf "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
