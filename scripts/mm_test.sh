#!/usr/bin/env bash
# Matchmaking integration: matchmaker + 2 queued headless clients -> one hosts, one joins, match starts.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
MMPORT="${MMPORT:-$((24700 + RANDOM % 200))}"
MODE="${MODE:-casual}"
QUEUE="$MODE"; PARTY=""
if [ "$MODE" = "party" ]; then QUEUE=casual; PARTY="--party=PALS:2"; fi
if [ "$MODE" = "chaos" ]; then QUEUE=casual; PARTY="--mode=chaosball"; fi
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
timeout 60 "$GODOT" --headless --path . -- --matchmaker --port="$MMPORT" > .mm-server.log 2>&1 &
MM=$!
sleep 1
timeout 55 "$GODOT" --headless --path . -- --queue=$QUEUE $PARTY --mm=127.0.0.1:"$MMPORT" --size=3 --advertise=127.0.0.1 --name=Ann --rating=1000 --profile-file=user://test_mm_profile.json --leaderboard-file=user://test_mm_lb.json --ranked-file=user://test_mm_ranked.json > .mm-a.log 2>&1 &
A=$!
sleep 0.5
timeout 55 "$GODOT" --headless --path . -- --queue=$QUEUE $PARTY --mm=127.0.0.1:"$MMPORT" --size=3 --advertise=127.0.0.1 --name=Ben --rating=1050 --profile-file=user://test_mm_b_profile.json --leaderboard-file=user://test_mm_b_lb.json --ranked-file=user://test_mm_b_ranked.json > .mm-b.log 2>&1 &
B=$!
ok=0
for i in $(seq 1 450); do
  if grep -q "NET match started" .mm-a.log .mm-b.log 2>/dev/null && grep -q "NET assigned athlete" .mm-a.log .mm-b.log 2>/dev/null; then ok=1; break; fi
  sleep 0.1
done
kill $A $B $MM 2>/dev/null; wait $A $B $MM 2>/dev/null
grep -hE "^MM |^QUEUE|NET match started|NET seats|NET assigned" .mm-server.log .mm-a.log .mm-b.log
if grep -hE "SCRIPT ERROR|Parse Error" .mm-server.log .mm-a.log .mm-b.log | grep -q .; then
  grep -hE "SCRIPT ERROR|Parse Error|at: " .mm-server.log .mm-a.log .mm-b.log | head; echo "MM TEST FAIL (script errors)"; exit 1
fi
# The started match must be the queued 3v3 with both humans in it.
# The started match must be the queued 3v3 with both named humans in it.
if [ $ok -eq 1 ] && grep -qE "NET match started: (Chaosball )?3v3.*(Ann ✓, Ben ✓|Ben ✓, Ann ✓)" .mm-a.log .mm-b.log; then
  if [ "$MODE" = "competitive" ]; then
    # Rating-balanced snake draft: Ben (1050) -> team 0, Ann (1000) -> team 1, and the match is ranked.
    grep -qE "NET seats: .*(Ben->0.*Ann->1|Ann->1.*Ben->0).*ranked=true" .mm-a.log .mm-b.log || { echo "MM TEST FAIL (competitive seating)"; exit 1; }
  fi
  if [ "$MODE" = "chaos" ]; then
    grep -qE "NET match started: Chaosball 3v3" .mm-a.log .mm-b.log || { echo "MM TEST FAIL (chaosball mode)"; exit 1; }
  fi
  if [ "$MODE" = "party" ]; then
    # Friends who queued as a party must be seated together.
    grep -qE "NET seats: .*(Ann->0.*Ben->0|Ben->0.*Ann->0|Ann->1.*Ben->1|Ben->1.*Ann->1)" .mm-a.log .mm-b.log || { echo "MM TEST FAIL (party split)"; exit 1; }
  fi
  echo "MM TEST PASS ($MODE)"; exit 0
fi
echo "MM TEST FAIL"; exit 1
