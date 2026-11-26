# docs/: where knowledge lives

Agents start from `AGENTS.md`. This file says which doc owns what, so each fact has one home.

**Work** (backlog, bugs, ideas, status, decisions) is not in docs. It lives in **GitHub issues**; see `workflow.md`. Docs describe how the game *is* and how it's *built*, and they link to the issues that will change them.

## Two levels of docs

| Level | Path | Answers | Update it when |
|---|---|---|---|
| Feature | `features/<area>.md` (index: `features/README.md`) | What does the player experience? Rules, controls, numbers, decisions, what didn't work, open issues | Player-facing behavior in that area changes (same commit) |
| Design | `design/<topic>.md` | How is it built? Architecture, protocols, data flow, invariants, extension points | You add or change a subsystem, protocol or cross-cutting rule |

## Everything else

| Path | Owns | Update it when |
|---|---|---|
| `workflow.md` | How work is tracked in GitHub issues: labels, claim/close, side findings, body format | The process changes |
| `vision.md` | Pitch, pillars, assumptions, problems → fixes, original roadmap | Pillars or direction change (owner call) |
| `TESTING.md` | How to test without opening a window: every script, tier and harness | You add or change a test script, harness flag or gate |
| `optimization/README.md` | Performance best practices, budgets, measuring tools | You learn a new perf rule or change a budget |
| `optimization/LOG.md` | Dated before/after measurements, newest first | You make (or try) any perf change: numbers or it didn't happen |
| `iterations/NNN-slug.md` | One loop iteration's design pass (starts with `Issue: #N`) | You start an iteration (LOOP.md step 3) |
| `PARITY.md` | Gridiron parity audit (`G##` rows with test evidence; read by `scripts/parity_audit.sh`) | A parity feature lands or a gap is found (gaps → issues labelled `parity`) |
| `research/` | Gap analysis vs Gridiron/genre and dated review logs; `REEVALUATE.md` is the scheduled review procedure | Per `research/REEVALUATE.md` |
| `backlog/legacy-ids.md` | Old `A/B/C/D##` ids → GitHub issue numbers | Never (frozen 2026-11-25) |

Repo-root files: `AGENTS.md` (entry point), `LOOP.md` (the iteration procedure), `ITERATIONS.md` (the iteration log), `ASSETS.md` (licenses for every third-party asset). `FEATURES.md` and `docs/gaps/TODO.md` are stubs pointing to the issues.

## Writing rules
- **One home per fact.** Link to it instead of restating it. If two docs disagree, fix the one that isn't the owner listed above. If the code disagrees with a doc, the code wins: fix the doc, and open an issue if the code is the thing that's wrong.
- **Numbers carry a date, the machine and the mode** ("GPU d3d12, 2026-11-25"). Undated perf numbers rot.
- **Write what didn't work** in the feature doc's "Design decisions" or the relevant log. That's the most valuable thing for the next agent.
- **Docs ship with the change**, in the same commit. A behavior change without its doc update is unfinished.
- **No TODO lists in docs.** A to-do is an issue. A doc may link `#N` for "planned" work.
- Keep entries short: tables over prose, commands people can copy.
