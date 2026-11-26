#!/usr/bin/env bash
# Scheduled feature-gap re-evaluation (research docs + GitHub issues). Runs headless Claude Code against
# docs/research/REEVALUATE.md. Installed in the user's crontab; safe to run by hand.
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
PROMPT="Run the feature-gap re-evaluation for this repo by following docs/research/REEVALUATE.md exactly. Today is $(date +%F). The backlog lives in GitHub issues (gh CLI); file, comment on, re-rank and close issues as that procedure says. Edit nothing outside docs/research/, and commit with the docs/research pathspec only. Never push. End with a short summary of issues opened/closed/re-ranked (with numbers)."
timeout 45m "$CLAUDE" -p "$PROMPT" \
  --permission-mode acceptEdits \
  --allowedTools "Read" "Grep" "Glob" "Edit" "Write" "WebSearch" "WebFetch" \
    "Bash(git log:*)" "Bash(git status:*)" "Bash(git diff:*)" "Bash(git show:*)" \
    "Bash(git add docs/research:*)" "Bash(git commit:*)" "Bash(ls:*)" "Bash(date:*)" \
    "Bash(gh issue list:*)" "Bash(gh issue view:*)" "Bash(gh issue create:*)" "Bash(gh issue comment:*)" \
    "Bash(gh issue edit:*)" "Bash(gh issue close:*)" "Bash(gh label list:*)" \
  >> "$LOG" 2>&1
echo "=== $(date -Is) gap review exit $?" >> "$LOG"
