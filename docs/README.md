# docs/: where knowledge lives

Agents start from `AGENTS.md`. This file says which doc owns what, so each fact has one home.

| Path | Owns | Update it when |
|---|---|---|
| `TESTING.md` | How to test without opening a window: every script, tier and harness | you add or change a test script, harness flag or gate |
| `optimization/README.md` | Performance best practices, budgets, measuring tools | you learn a new perf rule or change a budget |
| `optimization/LOG.md` | Dated before/after measurements, newest first | you make (or try) any perf change: numbers or it didn't happen |
| `iterations/NNN-slug.md` | One loop iteration's design: goal, options, pick, acceptance criteria | you start an iteration (LOOP.md step 3) |
| `PARITY.md` | Gridiron parity audit (`G##` rows with test evidence) | a parity feature lands or a gap is found |
| `gaps/` | Living gap analysis and the Phase C TODO list (`C##`) | per `gaps/REEVALUATE.md` |

Repo-root files: `LOOP.md` (the iteration procedure), `PLAN.md` (vision and pillars),
`FEATURES.md` (the backlog, including `D##` "Discovered" bugs), `ITERATIONS.md` (the iteration log), `ASSETS.md`
(licenses for every third-party asset).

## Writing rules
- **One home per fact.** Link to it instead of restating it. If two docs disagree, fix the
  one that isn't the owner listed above.
- **Numbers carry a date, the machine and the mode** ("GPU d3d12, 2026-11-25"). Undated perf numbers rot.
- **Write what didn't work** in the relevant log. That's the most valuable thing for the next agent.
- **Docs ship with the change**, in the same commit. A behavior change without its doc
  update is unfinished.
- Keep entries short: tables over prose, commands people can copy.
