#!/usr/bin/env bash
# One-command first-time Supabase setup.
#
# Usage: ./scripts/bootstrap-supabase.sh
#
# This script is *idempotent* — re-running it on an already-set-up project
# is safe and useful for "I'm on a new machine" or "I rotated keys".
#
# What it does:
#   1. Verifies the Supabase CLI and Docker are installed.
#   2. Logs into Supabase if you haven't yet (opens a browser).
#   3. Asks if you want a local-only stack or to also link to a cloud project.
#   4. Starts local stack (Docker) and/or links/pushes to the cloud project.
#   5. Writes ios/Tempo/Supabase/SupabaseConfig.swift with the URLs/keys.
#
# What it does NOT do:
#   - Apple Developer Portal setup. That's a one-time human task, see
#     supabase/README.md §Apple Developer Portal.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

bold()  { printf "\033[1m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
yellow(){ printf "\033[33m%s\033[0m\n" "$*"; }
red()   { printf "\033[31m%s\033[0m\n" "$*" >&2; }

# ────────────────────────────────────────────────────────────────────────
# 1. prerequisites
# ────────────────────────────────────────────────────────────────────────

bold "→ Checking prerequisites"

if ! command -v supabase >/dev/null 2>&1; then
  yellow "Supabase CLI not found. Installing via Homebrew…"
  if ! command -v brew >/dev/null 2>&1; then
    red "Homebrew not found. Install from https://brew.sh first."
    exit 1
  fi
  brew install supabase/tap/supabase
fi
green "  supabase $(supabase --version)"

if ! command -v docker >/dev/null 2>&1; then
  red "Docker not found. Local Supabase needs Docker Desktop."
  red "Install from https://www.docker.com/products/docker-desktop"
  exit 1
fi
green "  docker $(docker --version | cut -d',' -f1)"

# ────────────────────────────────────────────────────────────────────────
# 2. login (no-op if already logged in)
# ────────────────────────────────────────────────────────────────────────

bold "→ Supabase login"
if supabase projects list >/dev/null 2>&1; then
  green "  Already logged in."
else
  supabase login
fi

# ────────────────────────────────────────────────────────────────────────
# 3. choose flavor
# ────────────────────────────────────────────────────────────────────────

bold "→ What do you want to set up?"
echo "  1) Local only (Docker)         — fast iteration, offline"
echo "  2) Cloud only (linked project)  — what TestFlight users hit"
echo "  3) Both (recommended)           — local for dev, cloud for prod"
read -r -p "Choice [3]: " choice
choice="${choice:-3}"

WANT_LOCAL=false
WANT_CLOUD=false
case "$choice" in
  1) WANT_LOCAL=true ;;
  2) WANT_CLOUD=true ;;
  3) WANT_LOCAL=true; WANT_CLOUD=true ;;
  *) red "Invalid choice."; exit 1 ;;
esac

# ────────────────────────────────────────────────────────────────────────
# 4. local stack
# ────────────────────────────────────────────────────────────────────────

LOCAL_URL=""
LOCAL_ANON=""
if $WANT_LOCAL; then
  bold "→ Starting local Supabase (this takes ~30s the first time)"
  supabase start 2>&1 | tail -30 || true

  bold "→ Applying migrations + seed to local DB"
  supabase db reset --local

  STATUS_JSON="$(supabase status -o json)"
  LOCAL_URL="$(echo "$STATUS_JSON"  | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("API_URL",""))')"
  LOCAL_ANON="$(echo "$STATUS_JSON" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("ANON_KEY",""))')"
  green "  Local API: $LOCAL_URL"
fi

# ────────────────────────────────────────────────────────────────────────
# 5. cloud project
# ────────────────────────────────────────────────────────────────────────

CLOUD_URL=""
CLOUD_ANON=""
if $WANT_CLOUD; then
  bold "→ Cloud project"

  PROJECT_REF=""
  if [ -f supabase/.temp/project-ref ]; then
    PROJECT_REF="$(cat supabase/.temp/project-ref)"
    yellow "  Found existing link to project: $PROJECT_REF"
    read -r -p "  Use this project? [Y/n]: " keep
    if [[ "${keep:-y}" =~ ^[Nn] ]]; then
      PROJECT_REF=""
      rm -f supabase/.temp/project-ref
    fi
  fi

  if [ -z "$PROJECT_REF" ]; then
    echo "  Existing projects:"
    supabase projects list || true
    echo
    read -r -p "  Project ref (or 'new' to create one): " PROJECT_REF
    if [ "$PROJECT_REF" = "new" ]; then
      read -r -p "  New project name [tempo]: " NAME
      NAME="${NAME:-tempo}"
      read -r -p "  Org slug (find on dashboard → Settings): " ORG
      read -r -s -p "  Database password (saved — write it down!): " DBPASS
      echo
      supabase projects create "$NAME" --org-id "$ORG" --db-password "$DBPASS" --region us-east-1
      PROJECT_REF="$(supabase projects list -o json | python3 -c 'import json,sys; ps=json.load(sys.stdin); print(next(p["id"] for p in ps if p["name"]=="'"$NAME"'"))')"
    fi
    supabase link --project-ref "$PROJECT_REF"
  fi

  bold "→ Pushing migrations to cloud"
  supabase db push --linked

  bold "→ Fetching cloud anon key"
  CLOUD_URL="https://${PROJECT_REF}.supabase.co"
  CLOUD_ANON="$(supabase projects api-keys --project-ref "$PROJECT_REF" -o json | python3 -c 'import json,sys; keys=json.load(sys.stdin); print(next(k["api_key"] for k in keys if k["name"]=="anon"))')"
  green "  Cloud API: $CLOUD_URL"
fi

# ────────────────────────────────────────────────────────────────────────
# 6. write SupabaseConfig.swift (gitignored)
# ────────────────────────────────────────────────────────────────────────

bold "→ Writing ios/Tempo/Supabase/SupabaseConfig.swift"
mkdir -p ios/Tempo/Supabase

USE_LOCAL_DEFAULT="true"
if $WANT_CLOUD && ! $WANT_LOCAL; then USE_LOCAL_DEFAULT="false"; fi

cat > ios/Tempo/Supabase/SupabaseConfig.swift <<EOF
// AUTO-GENERATED by scripts/bootstrap-supabase.sh. Do not commit.
// Re-run the bootstrap script to refresh keys.

import Foundation

enum SupabaseConfig {
    /// Switch between local Docker stack and the linked cloud project.
    /// DEBUG defaults to whichever you set up via the bootstrap script.
    /// Release builds always use cloud.
    static var url: URL {
        #if DEBUG
        return useLocal ? localURL : cloudURL
        #else
        return cloudURL
        #endif
    }

    static var anonKey: String {
        #if DEBUG
        return useLocal ? localAnonKey : cloudAnonKey
        #else
        return cloudAnonKey
        #endif
    }

    /// Toggle this to point dev builds at the cloud instead of localhost.
    private static let useLocal: Bool = ${USE_LOCAL_DEFAULT}

    private static let localURL    = URL(string: "${LOCAL_URL:-http://127.0.0.1:54321}")!
    private static let localAnonKey = "${LOCAL_ANON}"

    private static let cloudURL    = URL(string: "${CLOUD_URL:-https://example.supabase.co}")!
    private static let cloudAnonKey = "${CLOUD_ANON}"
}
EOF

green "  Wrote ios/Tempo/Supabase/SupabaseConfig.swift"

# ────────────────────────────────────────────────────────────────────────
# 7. done
# ────────────────────────────────────────────────────────────────────────

echo
bold "✓ Bootstrap complete"
echo
if $WANT_LOCAL; then
  echo "  Local stack running:"
  echo "    Studio:   http://127.0.0.1:54323"
  echo "    API:      $LOCAL_URL"
  echo "    DB:       postgresql://postgres:postgres@127.0.0.1:54322/postgres"
  echo "    Emails:   http://127.0.0.1:54324  (Inbucket — fake SMTP)"
  echo
  echo "  Stop with: supabase stop"
  echo "  Reset with: ./scripts/db-reset.sh"
fi
if $WANT_CLOUD; then
  echo "  Cloud project: $CLOUD_URL"
  echo "  Push schema changes with: ./scripts/db-push.sh"
fi
echo
echo "  Next: open Xcode and build. The app will use the local stack by default."
