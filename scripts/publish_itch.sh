#!/usr/bin/env bash
# Upload build/dist zips to itch.io with butler. Never runs implicitly:
# requires ITCH_TARGET=<user>/<game> and a logged-in butler (butler login) or BUTLER_API_KEY.
#   ITCH_TARGET=me/crater-bowl ./scripts/publish_itch.sh
set -euo pipefail
cd "$(dirname "$0")/.."
: "${ITCH_TARGET:?set ITCH_TARGET=<itch user>/<game slug>}"
command -v butler >/dev/null || { echo "Install butler: https://itch.io/docs/butler/"; exit 2; }
VERSION="$(tr -d '[:space:]' < VERSION)"
for ch in windows linux macos; do
  z="build/dist/CraterBowl-$VERSION-$ch.zip"
  [ -f "$z" ] || { echo "missing $z (run ./scripts/export.sh)"; exit 1; }
  butler push "$z" "$ITCH_TARGET:$ch" --userversion "$VERSION"
done
