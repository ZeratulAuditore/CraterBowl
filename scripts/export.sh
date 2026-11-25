#!/usr/bin/env bash
# Build release zips for every platform into build/dist/:
#   CraterBowl-<version>-windows.zip / -linux.zip / -macos.zip
# Needs Godot 4.3 export templates (~/.local/share/godot/export_templates/4.3.stable).
# Usage: ./scripts/export.sh [Linux|Windows|macOS ...]   (default: all)
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
VERSION="$(tr -d '[:space:]' < VERSION)"
PLATFORMS=("$@"); [ ${#PLATFORMS[@]} -eq 0 ] && PLATFORMS=(Linux Windows macOS)
TPL="$HOME/.local/share/godot/export_templates/4.3.stable"
[ -f "$TPL/linux_release.x86_64" ] || { echo "Missing export templates in $TPL (see docs/DISTRIBUTION.md)"; exit 2; }
# Keep project.godot + export presets in sync with VERSION
sed -i "s/^config\/version=.*/config\/version=\"$VERSION\"/" project.godot
sed -i "s/^application\/\(file\|product\)_version=.*/application\/\1_version=\"$VERSION.0\"/; s/^application\/\(short_\)\?version=.*/application\/\1version=\"$VERSION\"/" export_presets.cfg
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
rm -rf build/dist && mkdir -p build/dist
fail=0
for p in "${PLATFORMS[@]}"; do
  lower=$(echo "$p" | tr '[:upper:]' '[:lower:]')
  out=$(awk -v n="name=\"$p\"" '$0==n{f=1} f&&/^export_path=/{gsub(/export_path=|"/,"");print;exit}' export_presets.cfg)
  rm -rf "$(dirname "$out")"; mkdir -p "$(dirname "$out")"
  if ! timeout 600 "$GODOT" --headless --path . --export-release "$p" "$out" > "build/export-$lower.log" 2>&1 || [ ! -s "$out" ]; then
    echo "EXPORT FAIL $p (build/export-$lower.log)"; fail=1; continue
  fi
  zip="build/dist/CraterBowl-$VERSION-$lower.zip"
  if [ "$p" = macOS ]; then cp "$out" "$zip"   # Godot already zips the .app
  else
    cp deploy/README-player.txt "$(dirname "$out")/README.txt"
    python3 - "$(dirname "$out")" "$zip" <<'PY'
import os, sys, zipfile
src, dst = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(src):
        for f in files:
            p = os.path.join(root, f)
            info = zipfile.ZipInfo.from_file(p, os.path.relpath(p, src))
            info.compress_type = zipfile.ZIP_DEFLATED
            with open(p, "rb") as fh:
                z.writestr(info, fh.read())   # keeps the executable bit
PY
  fi
  echo "BUILT $zip ($(du -h "$zip" | cut -f1))"
done
# Boot check: the exported Linux build must start headless and run a practice drill cleanly.
if [ -x build/linux/CraterBowl.x86_64 ]; then
  log=$(timeout 60 build/linux/CraterBowl.x86_64 --headless --quit-after 240 -- --practice=passing \
        --profile-file=user://test_export_profile.json 2>&1)
  if echo "$log" | grep -E "SCRIPT ERROR|Parse Error" | grep -q . || ! echo "$log" | grep -q "Crater Bowl v$VERSION"; then
    echo "$log" | tail -20; echo "EXPORT BOOT CHECK FAIL"; fail=1
  else echo "EXPORT BOOT CHECK PASS (v$VERSION)"; fi
fi
exit $fail
