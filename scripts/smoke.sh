#!/usr/bin/env bash
# Boot the main scene headless for N frames; fail on any script/engine error.
set -uo pipefail
cd "$(dirname "$0")/.."
# Guard: tests must never write the player's real data files.
USERDATA="$HOME/.local/share/godot/app_userdata/Fourth & Long"
before=$(ls -l --time-style=+%s "$USERDATA"/{profile,leaderboard,ranked}.json 2>/dev/null)
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
timeout 150 "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/game_flow.gd > .flow-output.log 2>&1
flow=$?
grep -E "FLOW|GAME FLOW" .flow-output.log
if [ $flow -ne 0 ] || grep -E "SCRIPT ERROR|Parse Error" .flow-output.log | grep -q .; then
  grep -E "SCRIPT ERROR|Parse Error|at: " .flow-output.log | head; echo "GAME FLOW FAIL"; exit 1
fi
# Two-process online test (host + client over localhost)
./scripts/net_test.sh || exit 1
# Matchmaking: matchmaker + 2 queued clients
./scripts/mm_test.sh | tail -1 | grep -q "MM TEST PASS" || { echo "MM TEST FAIL"; exit 1; }
MODE=competitive ./scripts/mm_test.sh | tail -1 | grep -q "MM TEST PASS" || { echo "MM TEST FAIL (competitive)"; exit 1; }
MODE=party ./scripts/mm_test.sh | tail -1 | grep -q "MM TEST PASS" || { echo "MM TEST FAIL (party)"; exit 1; }
MODE=chaos ./scripts/mm_test.sh | tail -1 | grep -q "MM TEST PASS" || { echo "MM TEST FAIL (chaos)"; exit 1; }
echo "MM TEST PASS"
after=$(ls -l --time-style=+%s "$USERDATA"/{profile,leaderboard,ranked}.json 2>/dev/null)
if [ "$before" != "$after" ]; then echo "USER DATA TOUCHED BY TESTS: $after"; exit 1; fi
echo "USER DATA UNTOUCHED"
rm -f "$USERDATA"/test_*.json
