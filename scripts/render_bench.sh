#!/usr/bin/env bash
# Offscreen real-renderer benchmark (Xvfb; no desktop window). See docs/optimization/README.md.
#   ./scripts/render_bench.sh                 # Mesa llvmpipe (CPU): stable, comparable anywhere
#   GPU=1 ./scripts/render_bench.sh           # WSL: route GL through the real GPU (Mesa d3d12)
#   RENDERER=forward_plus ./scripts/render_bench.sh   # Vulkan path (llvmpipe in WSL)
#   ./scripts/render_bench.sh --frames=600 --size=3   # extra args reach main.gd
# Prints RBENCH key=value lines. Compare before/after on the SAME machine + mode only.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
RES="${RES:-1280x720}"
command -v xvfb-run >/dev/null || { echo "render_bench.sh needs xvfb-run: sudo apt install xvfb"; exit 2; }
drv=(--rendering-driver opengl3)
[ "${RENDERER:-}" = "forward_plus" ] && drv=(--rendering-driver vulkan --rendering-method forward_plus)
gpu=()
[ "${GPU:-0}" = "1" ] && gpu=(GALLIUM_DRIVER=d3d12)
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
LOG="$(mktemp "${TMPDIR:-/tmp}/rbench.XXXXXX.log")"
env -u WAYLAND_DISPLAY "${gpu[@]}" timeout "${TIMEOUT:-240}" \
  xvfb-run -a -s "-screen 0 ${RES}x24" \
  "$GODOT" --path . --display-driver x11 "${drv[@]}" --audio-driver Dummy --resolution "$RES" \
  -s res://tools/render_bench.gd -- --profile-file=user://test_rb_profile.json \
  --leaderboard-file=user://test_rb_lb.json --ranked-file=user://test_rb_ranked.json \
  --replay-dir=user://test_rb_replays "$@" > "$LOG" 2>&1
grep -E "^RBENCH " "$LOG" || { grep -E "ERROR|at: " "$LOG" | head; echo "RBENCH FAIL (log: $LOG)"; exit 1; }
