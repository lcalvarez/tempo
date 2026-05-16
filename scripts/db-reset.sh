#!/usr/bin/env bash
# Wipe the local DB and re-apply all migrations + seed data.
# Use after editing migrations or seed.sql to start from a known-clean state.
#
# Cloud DB is never touched by this script.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! supabase status >/dev/null 2>&1; then
  echo "→ Local stack isn't running. Starting…"
  supabase start
fi

echo "→ Resetting local DB"
supabase db reset --local

echo "✓ Local DB reset complete."
echo "  Studio: http://127.0.0.1:54323"
