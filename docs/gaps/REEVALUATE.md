# Gap re-evaluation procedure

This runs on a schedule (`tools/gap_review.sh`, from the user's crontab) and can also be run by hand. Each run re-checks what would make the game better and updates the TODOs. **It is docs only: never edit code, tests, `FEATURES.md`, `LOOP.md`, `PLAN.md` or `docs/PARITY.md`.** Other sessions own those files and may have uncommitted work in them.

## Steps
1. **Orient (read only).**
   - Read `docs/gaps/README.md`, `GAP_ANALYSIS.md`, `TODO.md`, and the newest file in `docs/gaps/reviews/`.
   - Read `FEATURES.md`, `docs/PARITY.md` (if present), the `ITERATIONS.md` entries since the last review's date, and `git log --oneline --since=<last review date>`.
2. **Close what shipped.** For each `[ ]` C item, check whether a commit or iteration implemented it. Grep the code to confirm; don't trust the checkbox alone.
   - Fully done: mark it `[x] (iter NNN)`.
   - Partly done: narrow its acceptance criteria to what's left.
   - Owned by another session: mark it `[~]` and say where.
3. **Re-check the code for new gaps.** Look at what the latest iterations added and list their "known gaps". Update the "Ours" column in `GAP_ANALYSIS.md` wherever it's now wrong.
4. **Re-check the outside world.** Keep it to ~6 searches and fetches:
   - Gridiron Remastered news: https://store.steampowered.com/news/app/3878710
   - Its store page: https://store.steampowered.com/app/3878710/
   - Steam discussions: https://steamcommunity.com/app/3878710/discussions/
   - New reviews, if any.
   - One rotating genre source: Rocket League patch notes, Rematch, Madden, or an indie football game.
   - Record only concrete, sourced mechanics/modes. If a site blocks fetches, note it and move on.
5. **Update the TODOs.**
   - New gap → new `C##` (the next unused number; never reuse ids) in the right priority band, with Why (source-tagged), testable acceptance criteria, and touch points.
   - A gap that duplicates a Phase A/B or `D##` item → an addendum, not a new id.
   - Re-rank if evidence changed. For example, if the remaster ships a mechanic, it may move to P0.
   - Don't pad: a run that finds nothing new says so.
6. **Log.** Write `docs/gaps/reviews/YYYY-MM-DD.md` with these sections:
   - Sources checked (URLs, and whether each was reachable)
   - What changed in the game since the last review
   - Items added, closed or re-ranked
   - Open questions for the user
   - Also update "Last evaluated" in `GAP_ANALYSIS.md`.
7. **Commit only this folder:** `git add docs/gaps && git commit -m "gaps: review YYYY-MM-DD" -- docs/gaps`.
   - The `-- docs/gaps` pathspec is mandatory, so other sessions' staged or unstaged work is never swept in.
   - Never push. Never commit if `git diff --cached --name-only` shows anything outside `docs/gaps/` after your add.

## Guardrails
- Mechanics and modes only. Never Gridiron's name, art, UI, characters or audio.
- Don't run the game windowed. Don't run the long test suites; this is a docs job.
- Stay within ~30 minutes. If something needs a user decision, put it under "Open questions" in the review log rather than guessing.
