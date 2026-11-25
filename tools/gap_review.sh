#!/usr/bin/env bash
# Scheduled feature-gap re-evaluation (docs only). Runs headless Claude Code against
# docs/gaps/REEVALUATE.md. Installed in the user's crontab; safe to run by hand.
# Logs: ~/.local/state/fourth-and-long/gap-review-YYYY-MM-DD.log
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE="${CLAUDE:-$HOME/.local/bin/claude}"
LOGDIR="$HOME/.local/state/fourth-and-long"
mkdir -p "$LOGDIR"
LOG="$LOGDIR/gap-review-$(date +%F).log"
exec 9>"$LOGDIR/gap-review.lock"
flock -n 9 || { echo "$(date -Is) already running" >> "$LOG"; exit 0; }

cd "$REPO" || exit 1
echo "=== $(date -Is) gap review start ($REPO)" >> "$LOG"
PROMPT="Run the feature-gap re-evaluation for this repo by following docs/gaps/REEVALUATE.md exactly. Today is $(date +%F). Docs only: edit nothing outside docs/gaps/, and commit with the docs/gaps pathspec only. Never push. End with a short summary of items added/closed/re-ranked."
timeout 45m "$CLAUDE" -p "$PROMPT" \
  --permission-mode acceptEdits \
  --allowedTools "Read" "Grep" "Glob" "Edit" "Write" "WebSearch" "WebFetch" \
    "Bash(git log:*)" "Bash(git status:*)" "Bash(git diff:*)" "Bash(git show:*)" \
    "Bash(git add docs/gaps:*)" "Bash(git commit:*)" "Bash(ls:*)" "Bash(date:*)" \
  >> "$LOG" 2>&1
echo "=== $(date -Is) gap review exit $?" >> "$LOG"
