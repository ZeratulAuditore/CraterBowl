# Feature gaps

This folder holds the living gap analysis for Fourth & Long. It compares what we have against (1) Gridiron / Gridiron Remastered and (2) the best ideas elsewhere in the arcade-sports genre. It then turns each gap into a buildable TODO.

| File | What it is |
|---|---|
| `GAP_ANALYSIS.md` | The matrix: category → what Gridiron has → what we have → gap → TODO id |
| `TODO.md` | Prioritized feature TODOs (`C01`…), each with why, acceptance criteria and touch points |
| `REEVALUATE.md` | The procedure the scheduled re-evaluation job follows (also usable by hand) |
| `reviews/YYYY-MM-DD.md` | One log per evaluation run: sources checked, what changed, items added/closed |

## How this fits with the rest of the docs
- `FEATURES.md` is still the loop's backlog. Phase A is parity, Phase B is better-than-Gridiron, and "Discovered" holds bugs (`D##`). Phase C points here: once A and B are done, the loop takes the first unchecked item in `TODO.md`.
- `docs/PARITY.md` is the A28 audit (`G##` rows, store-page features with test evidence). P0 items here are **parity gaps that PARITY.md doesn't list yet**: mechanics Gridiron shipped in patches but that aren't in its store blurb. When the A28 owner agrees, they become PARITY rows and `D##` items.
- `docs/iterations/NNN-*.md` is where an item gets its real design pass when the loop picks it up. TODO entries here are scoping, not designs.

## ID and status conventions
- IDs are `C01`, `C02`, … and are never reused. Do not use `G##` (PARITY.md) or `D##` (FEATURES Discovered).
- Status: `[ ]` todo, `[~]` in progress / owned elsewhere (say where), `[x]` shipped (iteration number), `[-]` dropped (one-line reason).
- Priority: **P0** = core football / parity hole a player notices in the first match. **P1** = online/social parity or a retention basic. **P2** = better-than-Gridiron or polish.
- If an item duplicates a Phase A/B or `D##` item, don't create a `C##`. Add an "addendum" under that item in TODO.md instead.

## Rules
- Mechanics and modes only. Never Gridiron's name, art, UI, characters or audio.
- Every claim about another game carries a source tag (see `reviews/` for URLs). If something is unverified, say so.
- This folder is docs only. Nothing here changes code.
