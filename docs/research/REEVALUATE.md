# Gap re-evaluation procedure

This runs on a schedule (`tools/gap_review.sh`, from the user's crontab) and can also be run by hand. Each run re-checks what would make the game better and keeps the **GitHub issues** current (`docs/workflow.md`). **It never edits code, tests, or any doc outside `docs/research/`.** Other sessions own those files and may have uncommitted work in them.

## Steps
1. **Orient (read only).**
   - Read `docs/research/README.md`, `gap-analysis.md`, and the newest file in `docs/research/reviews/`.
   - List the open issues: `gh issue list --state open --limit 200 --json number,title,labels`. Also list the ones closed since the last review: `gh issue list --state closed --search "closed:>=<last review date>"`.
   - Read the PRs merged since the last review's date (`gh pr list --state merged --search "merged:>=<date>"`), and `git log --oneline --since=<last review date>`.
2. **Reconcile issues with the code.** For each open feature/parity issue that recent commits might have touched, grep the code to confirm.
   - Fully shipped but still open: comment the evidence (commit, file) and close it. `gh issue close N --comment "Gap review YYYY-MM-DD: shipped in <sha> (<file>)."`
   - Partly shipped: comment what's left (narrow the scope). Don't close.
   - A stale `status:in-progress` claim (no commits on its branch for 3+ days): comment asking whether it's still active. Never remove someone else's claim.
3. **Re-check the code for new gaps.** Look at what the latest merged PRs added and the follow-ups they list. Each untracked gap → a new issue. Update the "Ours" column in `gap-analysis.md` wherever it's now wrong.
4. **Re-check the outside world.** Keep it to ~6 searches and fetches:
   - Gridiron Remastered news: https://store.steampowered.com/news/app/3878710
   - Its store page: https://store.steampowered.com/app/3878710/
   - Steam discussions: https://steamcommunity.com/app/3878710/discussions/
   - New reviews, if any.
   - One rotating genre source: Rocket League patch notes, Rematch, Madden, or an indie football game.
   - Record only concrete, sourced mechanics/modes. If a site blocks fetches, note it and move on.
5. **File and re-rank issues.**
   - First search for duplicates: `gh issue list --state all --search "<keywords>"`. A gap that's already covered becomes a comment on that issue, not a new issue.
   - New gap → `gh issue create` with labels `type:feature` (or `type:improvement`), `parity` if applicable, a priority and an area. The body follows the format in `docs/workflow.md`: Why (source-tagged), testable acceptance bullets, touch points, the feature doc to update, and "Found by gap review YYYY-MM-DD".
   - Re-rank when evidence changed (`gh issue edit N --add-label P0 --remove-label P1`) and comment why. For example, the remaster shipping a mechanic may move it to P0.
   - Owner questions → a `type:decision` issue, or the `question` label plus a comment on the relevant issue.
   - Don't pad: a run that finds nothing new says so.
6. **Log.** Write `docs/research/reviews/YYYY-MM-DD.md` with these sections:
   - Sources checked (URLs, and whether each was reachable)
   - What changed in the game since the last review
   - Issues opened, closed, commented and re-ranked (with numbers)
   - Open questions for the owner (with issue numbers)
   - Also update "Last evaluated" in `gap-analysis.md`.
7. **Commit only this folder:** `git add docs/research && git commit -m "research: gap review YYYY-MM-DD" -- docs/research`.
   - The `-- docs/research` pathspec is mandatory, so other sessions' staged or unstaged work is never swept in.
   - Never push. Never commit if `git diff --cached --name-only` shows anything outside `docs/research/` after your add.

## Guardrails
- Mechanics and modes only. Never Gridiron's name, art, UI, characters or audio.
- Issues are public: no secrets or personal details.
- Never delete issues. Never close `type:decision` issues; only the owner closes those.
- Don't run the game windowed. Don't run the long test suites; this is a research job.
- Stay within ~30 minutes. If something needs a user decision, open or label an issue rather than guessing.
