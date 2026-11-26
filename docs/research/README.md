# Research: feature gaps vs Gridiron and the genre

Outside research that feeds the backlog. It compares what we have against (1) Gridiron / Gridiron Remastered and (2) the best ideas elsewhere in the arcade-sports genre. **Findings become GitHub issues** (`docs/workflow.md`). This folder keeps the evidence and the reasoning, not the to-do list.

| File | What it is |
|---|---|
| `gap-analysis.md` | The matrix: category → what Gridiron has → what we have → gap → issue. Its legacy `C##` ids map to issues via `../backlog/legacy-ids.md`. |
| `REEVALUATE.md` | The procedure the scheduled re-evaluation job (`tools/gap_review.sh`, daily crontab) follows. Usable by hand too. |
| `reviews/YYYY-MM-DD.md` | One log per evaluation run: sources checked, what changed, issues opened/closed/re-ranked |

## Conventions
- A gap becomes an issue labelled `parity` (if Gridiron/the Remaster has it), a priority, and an area. The issue body carries the source tags.
- Source tags: **O** = original Gridiron patch notes, **R** = Gridiron Remastered, **R-ss** = the owner's remaster open-beta screenshots (2026-11-25), **R?** = original feature not yet confirmed in the remaster, **Gx** = other genre games, **PLAN** = `../vision.md`.
- `../PARITY.md` is the A28 audit (`G##` rows with test evidence). A parity gap found later gets an issue labelled `parity`. Add a PARITY row only when it ships with test evidence.

## Rules
- Mechanics and modes only. Never Gridiron's name, art, UI, characters or audio.
- Every claim about another game carries a source tag (see `reviews/` for URLs). If something is unverified, say so.
- This folder is docs only. Nothing here changes code.
