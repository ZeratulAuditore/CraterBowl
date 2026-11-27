#!/usr/bin/env bash
# A rendered fixture must propagate an assertion failure even after a PNG was saved.
set -euo pipefail
cd "$(dirname "$0")/.."

scratch="$(mktemp -d)"
out="$(realpath -m "${BEFORE_AFTER_TEST_OUTPUT:-$scratch}")"
fixture=tests/visual/before_after_status_fixture_test.gd
if [[ -e "$fixture" ]]; then
  echo "BEFORE/AFTER TEST FAIL: $fixture already exists" >&2
  rmdir "$scratch"
  exit 1
fi
trap 'rm -f "$fixture"; rm -rf "$scratch"' EXIT
mkdir -p "$out"

cat > "$fixture" <<'GDSCRIPT'
extends "res://tests/visual/harness.gd"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var label := Label.new()
	label.text = "Before/after test capture"
	label.position = Vector2(48, 48)
	label.add_theme_font_size_override("font_size", 36)
	root.add_child(label)
	await capture("before-exit")
	var side := OS.get_environment("VISUAL_CASE_OUTPUT").get_file()
	check(side != "visual-" + OS.get_environment("BEFORE_AFTER_TEST_FAIL_SIDE"), "fixture assertion after capture")
	finish()
GDSCRIPT

run_fixture() {
  BEFORE_AFTER_TEST_FAIL_SIDE="$1" ./scripts/before_after.sh --base=HEAD --out="$out/fail-$1" \
    visual before_after_status_fixture
}

shot=before_after_status_fixture-before-exit.png
status=0
run_fixture after > "$out/fail-after.log" 2>&1 || status=$?
cat "$out/fail-after.log"
if [[ $status -eq 0 ]] || grep -q '^BEFORE/AFTER OK' "$out/fail-after.log"; then
  echo "BEFORE/AFTER TEST FAIL: a branch assertion failure reported success" >&2
  exit 1
fi
grep -q '^VISUAL FAIL fixture assertion after capture' "$out/fail-after.log"
test -s "$out/fail-after/before/$shot"
test -s "$out/fail-after/after/$shot"

run_fixture before > "$out/fail-before.log" 2>&1
cat "$out/fail-before.log"
grep -q '^before: visual checks failed on the base' "$out/fail-before.log"
grep -q '^BEFORE/AFTER OK' "$out/fail-before.log"
test -s "$out/fail-before/compare/$shot"

echo "BEFORE/AFTER TEST PASS"
