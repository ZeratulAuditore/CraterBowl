#!/usr/bin/env bash
# Run each rendered integration test with isolated saves and output.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
command -v xvfb-run >/dev/null || { echo "Install Xvfb and xauth to run visual tests." >&2; exit 2; }
output="$(realpath -m "${VISUAL_OUTPUT:-$(mktemp -d)}")"
mkdir -p "$output"
userdata="$(mktemp -d)"
export XDG_DATA_HOME="$userdata/data" XDG_CONFIG_HOME="$userdata/config" XDG_CACHE_HOME="$userdata/cache"
trap 'rm -rf "$userdata"' EXIT
timeout 180 "$GODOT" --headless --path . --import

for test in tests/visual/*_test.gd; do
  name="$(basename "$test" .gd)"
  export VISUAL_CASE_OUTPUT="$(mktemp -d "$output/$name.XXXXXX")"
  log="$VISUAL_CASE_OUTPUT/run.log"
  if ! env -u WAYLAND_DISPLAY LIBGL_ALWAYS_SOFTWARE=1 timeout 120 \
      xvfb-run -a -s '-screen 0 1280x720x24' "$GODOT" --path . \
      --display-driver x11 --rendering-driver opengl3 --audio-driver Dummy \
      --resolution 1280x720 --fixed-fps 60 -s "res://$test" >"$log" 2>&1; then
    cat "$log"
    exit 1
  fi
  cat "$log"
  if grep -Eq 'SCRIPT ERROR|Parse Error' "$log" ||
      ! find "$VISUAL_CASE_OUTPUT" -maxdepth 1 -name '*.png' -size +0c -print -quit | grep -q .; then
    echo "VISUAL FAIL: $name reported a script error or produced no PNG." >&2
    exit 1
  fi
done
echo "VISUAL PASS ($output)"
