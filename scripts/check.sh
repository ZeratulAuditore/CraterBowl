#!/usr/bin/env bash
# The one gate. Run before every commit that touches code.
#   ./scripts/check.sh          full: lint + unit + perf + smoke (flow, net, matchmaking)  ~3-4 min
#   ./scripts/check.sh --fast   lint + unit + perf (what the pre-commit hook runs)          ~45 s
# Never opens a window. See docs/TESTING.md.
set -uo pipefail
cd "$(dirname "$0")/.."
start=$(date +%s)
step() {
  local name=$1; shift
  echo "== $name"
  if "$@" > "${TMPDIR:-/tmp}/fl-check-$$-$name.log" 2>&1; then
    echo "   ok ($name)"; rm -f "${TMPDIR:-/tmp}/fl-check-$$-$name.log"
  else
    tail -25 "${TMPDIR:-/tmp}/fl-check-$$-$name.log"; echo "CHECK FAIL: $name (full log: ${TMPDIR:-/tmp}/fl-check-$$-$name.log)"; exit 1
  fi
}
step lint ./scripts/lint.sh
step unit ./scripts/test.sh
step perf ./scripts/perf.sh
if [ "${1:-}" != "--fast" ]; then
  step smoke ./scripts/smoke.sh
fi
echo "CHECK PASS ($(( $(date +%s) - start ))s${1:+ $1})"
