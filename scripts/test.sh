#!/usr/bin/env bash
# Run all headless unit tests. Exit non-zero on failure.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . -s res://tests/run_tests.gd 2>&1 | tee .test-output.log
status=${PIPESTATUS[0]}
if grep -qE "SCRIPT ERROR|Parse Error" .test-output.log; then echo "Script errors detected"; exit 1; fi
exit "$status"
