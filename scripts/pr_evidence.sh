#!/usr/bin/env bash
# Publish before/after screenshot pairs for a PR and print a Before | After markdown table.
#
#   ./scripts/pr_evidence.sh <PR#> <OUT> [name ...]
#
# OUT is a ./scripts/before_after.sh output dir. Names (file names without .png, shell globs ok)
# pick which pairs to publish, in table order; default is every pair. Pick the ones that show the change.
# Captions come from OUT/captions.txt, one "name: what the reviewer should notice" per line;
# a name without a caption gets its file name as alt text, so write captions.
#
# Pushes an orphan branch pr-evidence/<PR#> (only PNGs, never merged) using git plumbing, so it
# touches no checkout. Re-running adds a commit on top, so links in older PR comments keep working.
# Image URLs are pinned to the commit sha. Paste the printed table under ### Testing.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $# -ge 2 ]] || { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
PR="$1"; OUT="$(realpath "$2")"; shift 2
[[ -d "$OUT/after" ]] || { echo "no $OUT/after: run ./scripts/before_after.sh first"; exit 2; }
REPO="${REPO:-$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || echo bpenwell/CraterBowl)}"
BRANCH="pr-evidence/$PR"

declare -A CAPTION=()
if [[ -f "$OUT/captions.txt" ]]; then
  while IFS= read -r line; do
    [[ "$line" == *:* && "$line" != \#* ]] || continue
    k="${line%%:*}"; v="${line#*:}"; CAPTION["${k// /}"]="${v# }"
  done < "$OUT/captions.txt"
fi

# Pairs in the order the names were given (globs expand alphabetically); default: all, sorted.
all=()
for f in "$OUT"/after/*.png "$OUT"/before/*.png; do
  [[ -e "$f" ]] || continue
  n="$(basename "$f" .png)"
  [[ " ${all[*]-} " == *" $n "* ]] || all+=("$n")
done
IFS=$'\n' all=($(sort <<<"${all[*]-}")); unset IFS
names=()
for pat in "${@:-*}"; do
  for n in "${all[@]}"; do
    [[ "$n" == $pat && " ${names[*]-} " != *" $n "* ]] && names+=("$n")
  done
done
[[ ${#names[@]} -gt 0 ]] || { echo "no PNGs matched in $OUT"; exit 1; }

entries=""
for n in "${names[@]}"; do
  for side in before after; do
    f="$OUT/$side/$n.png"
    [[ -e "$f" ]] && entries+="100644 blob $(git hash-object -w "$f")	${side}-$n.png"$'\n'
  done
done
tree="$(printf "%s" "$entries" | git mktree)"
parent=()
if tip="$(git ls-remote --heads origin "$BRANCH" | cut -f1)" && [[ -n "$tip" ]]; then
  git fetch -q origin "$BRANCH" && parent=(-p "$tip")
fi
base_note="$(cat "$OUT/base.txt" 2>/dev/null || echo "base")"
commit="$(echo "Before/after screenshots for #$PR (before: $base_note)" | git commit-tree "$tree" "${parent[@]}")"
git push -q origin "$commit:refs/heads/$BRANCH" 2>&1 | grep -v "^remote:" || true

raw="https://raw.githubusercontent.com/$REPO/$commit"
echo
echo "| What changed | Before (\`${base_note%% *}\`) | After (this PR) |"
echo "|---|---|---|"
for n in "${names[@]}"; do
  cap="${CAPTION[$n]:-$n}"
  b="_(new screen)_"; a="_(removed)_"
  [[ -e "$OUT/before/$n.png" ]] && b="![Before: $cap]($raw/before-$n.png)"
  [[ -e "$OUT/after/$n.png" ]] && a="![After: $cap]($raw/after-$n.png)"
  echo "| $cap | $b | $a |"
done
echo
echo "EVIDENCE OK  $BRANCH @ ${commit:0:7}  (${#names[@]} pairs)"
