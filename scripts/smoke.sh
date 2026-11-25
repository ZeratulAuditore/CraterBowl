#!/usr/bin/env bash
# Boot the main scene headless for N frames; fail on any script/engine error.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
FRAMES="${FRAMES:-300}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
timeout 60 "$GODOT" --headless --path . --quit-after "$FRAMES" > .smoke-output.log 2>&1
cat .smoke-output.log
# Known headless-only engine noise (Godot 4.3 dummy renderer has no mesh storage):
# any MeshInstance3D logs this. Verified with a 1-mesh repro project in iter 001.
ALLOW='Parameter "m" is null\.|mesh_storage\.h'
if grep -E "SCRIPT ERROR|Parse Error|ERROR:|at: " .smoke-output.log | grep -vE "$ALLOW" | grep -q .; then
  echo "SMOKE FAIL: errors during boot"; exit 1
fi
echo "SMOKE PASS ($FRAMES frames)"
# Scripted gameplay flow through the real scene
timeout 150 "$GODOT" --headless --path . -s res://tests/game_flow.gd > .flow-output.log 2>&1
flow=$?
grep -E "FLOW|GAME FLOW" .flow-output.log
if [ $flow -ne 0 ] || grep -E "SCRIPT ERROR|Parse Error" .flow-output.log | grep -q .; then
  grep -E "SCRIPT ERROR|Parse Error|at: " .flow-output.log | head; echo "GAME FLOW FAIL"; exit 1
fi
