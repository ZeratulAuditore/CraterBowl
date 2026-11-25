#!/usr/bin/env bash
# Boot the main scene headless for N frames; fail on any script error.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
FRAMES="${FRAMES:-300}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --quit-after "$FRAMES" 2>&1 | tee .smoke-output.log
if grep -qE "SCRIPT ERROR|Parse Error|ERROR:" .smoke-output.log; then
  echo "SMOKE FAIL: errors during boot"; exit 1
fi
echo "SMOKE PASS ($FRAMES frames)"
