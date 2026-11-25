#!/usr/bin/env bash
# Two-process network test: headless host + headless client over localhost.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
PORT="${PORT:-$((24000 + RANDOM % 1000))}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
timeout 40 "$GODOT" --headless --path . -- --host --port="$PORT" --playclock=4 > .net-host.log 2>&1 &
HOST=$!
sleep 1.5
timeout 35 "$GODOT" --headless --path . -s res://tests/net_client.gd -- --join=127.0.0.1 --port="$PORT" > .net-client.log 2>&1
status=$?
kill "$HOST" 2>/dev/null; wait "$HOST" 2>/dev/null
grep -E "NET " .net-client.log
if [ $status -ne 0 ] || grep -E "SCRIPT ERROR|Parse Error" .net-client.log .net-host.log | grep -q .; then
  grep -E "SCRIPT ERROR|Parse Error|at: " .net-client.log .net-host.log | head; echo "NET TEST FAIL"; exit 1
fi
echo "NET TEST PASS"
