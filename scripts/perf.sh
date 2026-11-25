#!/usr/bin/env bash
# Performance gate (headless, GPU-independent). ~30s. Exit non-zero over budget.
#   1. Render budget: triangles / instances / shadow casters / materials in the real scene.
#   2. CPU budget: sim stages + scene script time per tick (tools/bench.gd).
# Budgets are deliberately ~5x current cost so machine noise never fails it; they catch
# order-of-magnitude regressions (an O(n^2) loop, a per-frame mesh rebuild, 4k-tri spheres).
# Numbers, history and how to tighten: docs/optimization/README.md + docs/optimization/LOG.md.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
# Medians (p50): robust to other processes on the box. See docs/optimization/README.md#budgets.
SIM_TICK_P50_US="${SIM_TICK_P50_US:-800}"       # measured ~130 us (7v7, all bots, idle box)
SCENE_FRAME_P50_US="${SCENE_FRAME_P50_US:-3000}" # measured ~430 us (whole tick: sim + views + HUD)
ARGS=(-- --profile-file=user://test_perf_profile.json --leaderboard-file=user://test_perf_lb.json
  --ranked-file=user://test_perf_ranked.json --replay-dir=user://test_perf_replays)
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
fail=0
rb=$(timeout 60 "$GODOT" --headless --path . -s res://tests/render_budget.gd "${ARGS[@]}" 2>&1)
echo "$rb" | grep -E "^BUDGET|RENDER BUDGET|SCRIPT ERROR"
echo "$rb" | grep -q "RENDER BUDGET PASS" || fail=1
b=$(timeout 120 "$GODOT" --headless --fixed-fps 60 --path . -s res://tools/bench.gd "${ARGS[@]}" --minutes=2 --frames=600 2>&1)
echo "$b" | grep -E "^BENCH .*(p50|p99)" | sed 's/^/  /'
val() { echo "$b" | grep -E "^BENCH $1=" | head -1 | cut -d= -f2 | cut -d. -f1; }
check() {  # name measured budget
  if [ -z "$2" ]; then echo "PERF FAIL: $1 not measured (bench crashed?)"; fail=1
  elif [ "$2" -gt "$3" ]; then echo "PERF FAIL: $1 = $2 us > budget $3 us"; fail=1
  else echo "PERF OK   $1 = $2 us (budget $3)"; fi
}
check sim_tick_p50 "$(val sim_tick_p50_us)" "$SIM_TICK_P50_US"
check scene_frame_p50 "$(val scene_frame_p50_us)" "$SCENE_FRAME_P50_US"
growth=$(echo "$b" | grep -E "^BENCH scene_object_growth=" | cut -d= -f2)
if [ "${growth:-0}" -gt 50 ]; then echo "PERF FAIL: $growth objects leaked over 600 frames (per-frame allocation?)"; fail=1; else echo "PERF OK   object growth = ${growth:-?} over 600 frames"; fi
USERDATA="$HOME/.local/share/godot/app_userdata/Fourth & Long"
rm -rf "$USERDATA"/test_perf_* 2>/dev/null
[ $fail -eq 0 ] && echo "PERF PASS" || echo "PERF FAIL"
exit $fail
