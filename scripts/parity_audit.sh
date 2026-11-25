#!/usr/bin/env bash
# A28 parity audit: run all suites, then verify every evidence line in docs/PARITY.md.
# Exit 0 only when every non-PENDING feature passes and no GAP remains.
set -uo pipefail
cd "$(dirname "$0")/.."
if [ -z "${SKIP_RUN:-}" ]; then   # SKIP_RUN=1 re-checks the last run's logs
  ./scripts/test.sh > /dev/null 2>&1
  ./scripts/smoke.sh > .parity-smoke.log 2>&1
  ./scripts/mm_test.sh > .parity-mm-casual.log 2>&1
  MODE=competitive ./scripts/mm_test.sh > .parity-mm-competitive.log 2>&1
  MODE=party ./scripts/mm_test.sh > .parity-mm-party.log 2>&1
  MODE=chaos ./scripts/mm_test.sh > .parity-mm-chaos.log 2>&1
  # Presentation: real renderer, offscreen (never a desktop window). Inspect the PNGs too.
  ./scripts/shot.sh --out="$PWD/.parity-shots/shot" --frames=90,240 --snap=60 > .parity-shots.log 2>&1
fi

check() { # kind pattern
  case "$1" in
    unit) grep -qF "PASS $2" .test-output.log ;;
    flow) grep -qF "FLOW OK   $2" .flow-output.log ;;
    net)  grep -qF "NET OK   $2" .net-client.log ;;
    menu) grep -qF "MENU OK   $2" .menu-flow.log ;;
    shot) grep -qF "$2" .parity-shots.log ;;
    mm)   grep -qhF "$2" .parity-mm-casual.log .parity-mm-competitive.log .parity-mm-party.log .parity-mm-chaos.log 2>/dev/null ;;
    *) return 1 ;;
  esac
}

declare -A ok missing
while read -r _ id kind rest; do
  if check "$kind" "$rest"; then ok[$id]=$(( ${ok[$id]:-0} + 1 )); else missing[$id]="${missing[$id]:-} [$kind] $rest;"; fi
done < <(grep -E '^EVIDENCE ' docs/PARITY.md)

fail=0; pending=0; gaps=0
while IFS='|' read -r _ id feat _ status _; do
  id=$(echo "$id" | xargs); feat=$(echo "$feat" | xargs); status=$(echo "$status" | xargs)
  [[ "$id" =~ ^G[0-9]+$ ]] || continue
  if [[ "$status" == PENDING* ]]; then echo "  PENDING $id $feat ($status)"; pending=$((pending+1)); continue; fi
  if [[ "$status" == GAP* ]]; then echo "  GAP     $id $feat ($status)"; gaps=$((gaps+1)); continue; fi
  if [ -n "${missing[$id]:-}" ] || [ -z "${ok[$id]:-}" ]; then
    echo "  FAIL    $id $feat ->${missing[$id]:- no evidence}"; fail=$((fail+1))
  else
    echo "  PASS    $id $feat (${ok[$id]} checks)"
  fi
done < docs/PARITY.md
echo "PARITY: fail=$fail gaps=$gaps pending=$pending"
[ $fail -eq 0 ] && [ $gaps -eq 0 ] && [ $pending -eq 0 ] && { echo "PARITY AUDIT PASS"; exit 0; }
echo "PARITY AUDIT NOT YET PASSING"; exit 1
