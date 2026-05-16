#!/usr/bin/env bash
# Build, install, and launch Tempo on the iOS Simulator.
#
# Usage:
#   ./run.sh                 # build + reinstall + relaunch (default)
#   ./run.sh build           # build only
#   ./run.sh launch          # install + launch (skip build)
#   ./run.sh clean           # wipe DerivedData and rebuild
#   ./run.sh logs            # tail the running app's stdout/stderr
#   ./run.sh devices         # list available simulator destinations
#
# Override the simulator with the SIM env var:
#   SIM="iPhone 17" ./run.sh
set -euo pipefail

# ─── Config ────────────────────────────────────────────────
SIM="${SIM:-iPhone 17 Pro}"
SCHEME="Tempo"
BUNDLE_ID="com.tempo.app"
PROJECT="Tempo.xcodeproj"

cd "$(dirname "$0")"

# ─── Helpers ───────────────────────────────────────────────
APP_PATH() {
  # Glob expansion happens at call time so a fresh clean build is picked up.
  ls -td ~/Library/Developer/Xcode/DerivedData/Tempo-*/Build/Products/Debug-iphonesimulator/Tempo.app 2>/dev/null | head -1
}

ensure_booted() {
  # Boot the sim if it isn't already; ignore "Unable to boot device in current state: Booted".
  xcrun simctl boot "$SIM" 2>/dev/null || true
  open -a Simulator
  # Wait for it to actually finish booting.
  xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1 || true
}

build() {
  echo "→ Building for ${SIM}…"
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,name=$SIM" \
    -configuration Debug \
    build \
    | xcbeautify 2>/dev/null \
    || xcodebuild \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,name=$SIM" \
        -configuration Debug \
        build
}

install_and_launch() {
  local app
  app="$(APP_PATH)"
  if [[ -z "$app" ]]; then
    echo "No built app found. Running build first."
    build
    app="$(APP_PATH)"
  fi
  ensure_booted
  echo "→ Installing $app"
  xcrun simctl install booted "$app"
  echo "→ Launching $BUNDLE_ID"
  # --terminate-running-process replaces an already-running instance with the new binary.
  xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch booted "$BUNDLE_ID"
}

# ─── Subcommands ───────────────────────────────────────────
case "${1:-all}" in
  all)
    build
    install_and_launch
    ;;
  build)
    build
    ;;
  launch)
    install_and_launch
    ;;
  clean)
    echo "→ Wiping DerivedData"
    rm -rf ~/Library/Developer/Xcode/DerivedData/Tempo-*
    build
    install_and_launch
    ;;
  logs)
    # Stream stdout/stderr from the running app.
    xcrun simctl spawn booted log stream \
      --level=debug \
      --predicate "process == \"Tempo\""
    ;;
  devices)
    xcrun simctl list devices available | grep -E '^\s*iPhone' || true
    ;;
  *)
    echo "Usage: $0 [all|build|launch|clean|logs|devices]"
    exit 1
    ;;
esac
