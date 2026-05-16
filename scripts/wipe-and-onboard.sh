#!/usr/bin/env bash
# scripts/wipe-and-onboard.sh
#
# Reset the simulator app to a true cold-start state — uninstalled,
# database wiped, no cached auth tokens — then relaunch. The next
# launch goes through onboarding from screen 1, exactly the way a
# real first-time TestFlight tester would experience it.
#
# Why a script instead of a manual workflow:
#   • `xcrun simctl uninstall` alone leaves cached profile rows
#     server-side (and old auth.users rows for the anon UUIDs) which
#     can poison "fresh start" testing.
#   • This script wipes the local DB too so the partner side of pair
#     tests starts clean as well.
#   • Repeatable: run before any manual cold-path verification.
#
# Usage:
#   ./scripts/wipe-and-onboard.sh                 # full reset + relaunch
#   ./scripts/wipe-and-onboard.sh --keep-db       # only wipe the app
#   ./scripts/wipe-and-onboard.sh --no-launch     # wipe but don't open app
set -euo pipefail

KEEP_DB=false
NO_LAUNCH=false
for arg in "$@"; do
  case "$arg" in
    --keep-db)   KEEP_DB=true   ;;
    --no-launch) NO_LAUNCH=true ;;
    *) echo "Unknown flag: $arg" >&2; exit 2 ;;
  esac
done

UDID="$(xcrun simctl list devices booted | grep -oE '[A-F0-9-]{36}' | head -1 || true)"
if [[ -z "$UDID" ]]; then
  echo "No booted simulator. Run 'cd ios && ./run.sh launch' once first." >&2
  exit 1
fi

echo "▸ Uninstalling com.tempo.app from simulator $UDID"
xcrun simctl uninstall "$UDID" com.tempo.app >/dev/null 2>&1 || true

if ! $KEEP_DB; then
  echo "▸ Resetting local Supabase DB (re-applies all migrations + seed)"
  supabase db reset --local >/dev/null 2>&1 \
    || { echo "✗ supabase db reset failed — is 'supabase start' running?" >&2; exit 1; }
fi

if $NO_LAUNCH; then
  echo "✓ Wiped. Re-install with: cd ios && ./run.sh launch"
  exit 0
fi

echo "▸ Reinstalling + launching"
cd "$(dirname "$0")/../ios"
./run.sh launch | tail -3

echo
echo "✓ Cold start ready. The simulator should now be on the welcome screen."
echo "  Walk through onboarding fresh. No cached profile, no cached auth."
