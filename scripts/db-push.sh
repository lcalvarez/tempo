#!/usr/bin/env bash
# Push local migrations to the linked cloud Supabase project.
#
# Workflow:
#   1. Create a migration:    supabase migration new add_my_feature
#   2. Edit the new .sql file under supabase/migrations/
#   3. Test locally:          ./scripts/db-reset.sh
#   4. When happy:            ./scripts/db-push.sh

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [ ! -f supabase/.temp/project-ref ]; then
  echo "✗ No linked cloud project found. Run ./scripts/bootstrap-supabase.sh first."
  exit 1
fi

PROJECT_REF="$(cat supabase/.temp/project-ref)"
echo "→ Pushing to cloud project: $PROJECT_REF"

# Dry-run preview so you see what'll change before you commit to it.
echo "→ Pending changes:"
supabase db diff --linked || true
echo

read -r -p "Apply these to cloud? [y/N]: " yn
if [[ ! "${yn:-n}" =~ ^[Yy] ]]; then
  echo "Aborted."
  exit 0
fi

supabase db push --linked
echo "✓ Cloud schema up to date."
