#!/usr/bin/env bash
# Two-process network test: headless host (5v5) + headless client (default 7v7, must adopt host size).
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
PORT="${PORT:-$((24000 + RANDOM % 1000))}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
timeout 40 "$GODOT" --headless --path . -s res://tests/net_host.gd -- --host --port="$PORT" --playclock=4 --size=5 --start-when-ready --advertise=127.0.0.1 --profile-file=user://test_net_profile.json --leaderboard-file=user://test_net_lb.json --ranked-file=user://test_net_ranked.json > .net-host.log 2>&1 &
HOST=$!
# Join the private lobby by its invite code (printed by the host).
CODE=""
for i in $(seq 1 50); do
  CODE=$(grep -oE "invite code: [0-9A-Z]{5}-[0-9A-Z]{5}" .net-host.log | awk '{print $3}')
  [ -n "$CODE" ] && break
  sleep 0.1
done
echo "invite code: ${CODE:-<none>}"
timeout 35 "$GODOT" --headless --path . -s res://tests/net_client.gd -- --join="$CODE" --equip=number:88 --profile-file=user://test_net_client_profile.json > .net-client.log 2>&1
status=$?
kill "$HOST" 2>/dev/null; wait "$HOST" 2>/dev/null
grep -E "NET " .net-client.log
if [ $status -ne 0 ] || grep -E "SCRIPT ERROR|Parse Error" .net-client.log .net-host.log | grep -q .; then
  grep -E "SCRIPT ERROR|Parse Error|at: " .net-client.log .net-host.log | head; echo "NET TEST FAIL"; exit 1
fi
echo "NET TEST PASS"
