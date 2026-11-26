# Regression baselines: sim goldens and visual goldens

Status: **design approved 2026-11-25, not built yet.** Tracking: #121. Once each phase lands, the
commands and flags move to `docs/TESTING.md` (the owner of "how to test"); this doc keeps the design.

## Problem

Crater Bowl is scaling to three human developers. Each one drives their own agents on their own
machine (Windows, macOS, Linux/WSL), and all three share review and merge rights. Today's gates check
that behavior is *correct* wherever someone wrote an assertion. Nothing notices when gameplay
outcomes or visuals *change*. Unasserted changes slip through, and with three people they get much
more likely, because each reviewer sees only their own slice:

| Slipped past green CI | Kind |
|---|---|
| #93 end-zone paint never follows possession | visual |
| #110 Chaosball throw arc ignores arena walls | visual |
| #115 game overview stats column clipped under the scrollbar | visual |
| #75 running clock shown in the private lobby | visual |

`tests/visual/` already captures named PNGs of real states, but they're only evidence for a human to
look at. Nothing compares them with anything.

## Goal and non-goals

**Goal:** any change to gameplay outcomes or to a rendered scene is impossible to miss in the PR that
causes it. An intended change takes one glance to approve. An unintended one fails CI.

**Non-goals:** judging whether a change is *good* or fun, AI review of screenshots, long nightly
soaks, and perf trends (`scripts/perf.sh` owns perf).

## Approach

Two layers, shipped in this order:

1. **Sim goldens.** About 80 short, independent fixed-setup situations each write one outcome line,
   committed in the repo. Long seeded bot games add invariants and ranged stats. All of it runs
   headless on any OS in seconds.
2. **Visual goldens.** CI renders every visual capture at the PR's merge-base and at the PR head, in
   the same job, and diffs them. No baseline PNGs are stored.

Both depend on a property the repo already enforces: `src/sim` has no engine, time or random calls
(lint rule), rolls are derived from the play situation (`World` "deterministic pseudo-random roll"),
the coin toss comes from a seed, and `tests/test_determinism.gd` proves two bot games are bit-identical.

## Phase 1: sim goldens

### Why not one long game

The sim is deterministic but chaotic. In a chained game, each play starts where the last one ended,
so if play 3 gains one more yard, every later play starts from a different spot and plays out
differently. Any small tweak then rewrites most of the log. A diff that big gets skimmed, agents
run `--update` just to go green, and real regressions slip through anyway. So exact-match goldens
come only from **short, independent situations**. Long games are kept for invariants and
**ranged** stats only.

### Situations (exact-match lines)

`tests/golden/situations.gd` holds a table of fixed starting states. Each situation sets up the
exact state (ruleset and size, offense, down and distance, line of scrimmage, half and clock, the
offensive play call, and the defensive call where the AI accepts one), then runs headless with
`dt = 1/60` from the snap to the whistle. Kicks run through the return. Each situation is capped at
15 s of sim time and produces **one line**. Nothing carries over from one situation to the next.

| Group | Matrix | About |
|---|---|---|
| 7v7 offense | every offensive play in the call menu × {own 25 1&10, midfield 3&4, opp 8 2&goal} | 40 |
| 3v3 | each 3v3 play × {own 25, opp 10} | 15 |
| Chaosball | possession starts × arena zones | 10 |
| Special teams | kickoff, onside, punt, FG from 30/45/55, PAT, 2-pt try | 10 |
| Clock | short series of at most 4 plays from a fixed state: 2:00 left trailing by 3, 0:40 left with no timeouts (spike, run-off, out of bounds) | 6 |

Line format, readable in a diff:

```
7v7 MESH        OWN25 1&10  → catch #13 @OWN33 +8                     | 4.2s
7v7 DEEP_SHOT   MID   3&4   → INT #22 @NEB41 ret 12                   | 3.1s
ST  FG45        OPP28 4&6   → good 3pts                               | 2.6s
```

Situation ids are stable keys (`7v7 MESH OWN25 1&10`). A change to Mesh moves only the Mesh lines.
A global change, such as player speed, moves many lines, and the summary (below) says so up front.

**Positions and velocities are excluded on purpose.** They change with every movement tweak and
would turn the file into noise. Lines record outcomes a player would notice. `test_determinism.gd`
stays the bit-level guard.

### Long games (ranges, not exact lines)

Three seeded all-bot games (`7v7_full_half`, `3v3_full_half`, `chaosball`), built from the same loop
as `test_determinism.gd`, check two things:

- **Tick invariants** on every tick (below).
- **Stat ranges:** completion %, yards per play, sacks, turnovers, average air yards, points per
  half, and plays per half. Each is checked against a range in `tests/golden/stat_ranges.cfg`
  (example: `7v7 completion_pct = 50..75`). The exact values are printed for information and never
  compared. Each range carries a comment with the reason for its bounds. Moving a range is a
  deliberate balance change: the PR says so, with the old and new range and why.

### Tick invariants

Both runners assert these every tick. A breach fails immediately, naming the situation or game,
the tick and the play:

- No NaN or infinite positions or velocities. No athlete or ball outside the world bounds.
- The ball is in exactly one state: held by one athlete, in flight, or dead.
- The score changes only on the tick of a scoring event, by that event's points.
- Down is 1–4, distance > 0, and the line of scrimmage is on the field.

### Commands and output

| Command | Does |
|---|---|
| `./scripts/golden.sh` | Runs every situation and long game. Compares situation lines with `tests/golden/situations.golden.txt` and stats with their ranges. Exits 1 on any changed line, out-of-range stat or invariant breach |
| `./scripts/golden.sh --update` | Rewrites `situations.golden.txt` from the current code. It never touches `stat_ranges.cfg`: ranges are edited by hand, with a reason |
| `./scripts/golden.sh <filter>` | Runs only the situations whose id matches the filter, for example `MESH` or `ST` |

**Summary first, then detail.** On a difference, `golden.sh` prints a summary before the diff:

```
GOLDEN: 9/81 situations changed (7v7 MESH ×3, 7v7 SLANTS ×3, 3v3 SLANTS ×3); stat ranges ok; invariants ok
```

then a unified diff of the changed lines only. The summary is what a reviewer checks against the
PR's claim. A PR that says it touched kickoffs and shows `61/81 changed` is the red flag.

Total run time budget: **≤ 30 s** on the WSL box, so it can sit in `check.sh --fast`.

### Workflow

- `golden.sh` joins the `unit` tier of `check.sh`, which `--fast` also runs, so the pre-commit path and CI both run it.
- A PR that changes gameplay commits the regenerated `situations.golden.txt` and pastes the
  `GOLDEN:` summary under `### Testing`, with one sentence for each group that moved, saying why.
  `.github/pull_request_template.md` gets that prompt.
- **Never hand-edit `situations.golden.txt`.** When two PRs both move it, the second one merges
  `origin/main`, resolves the conflict by running `--update` (it overwrites the conflicted file from
  the merged code), and commits the result. The `unit` tier fails when regenerated output differs
  from the committed file, so a skipped or botched `--update` can't land. (No custom `.gitattributes`
  merge driver: those need per-clone git config the other developers wouldn't have.)

### Failure handling

- A situation that crashes or hits its 15 s cap fails with its id and log. A long game that crashes
  or runs past 60 s fails with its log and the last play number.
- A situation with no line in the golden file fails with "no baseline: run `./scripts/golden.sh --update`".
  A new situation lands together with its line.

## Phase 2: visual goldens

### Render both sides, store nothing

Mac and Windows can't run Xvfb, and llvmpipe output can vary with the CPU and the Mesa version, so
stored baseline PNGs would be noisy and couldn't be reproduced locally. Instead, the PR workflow:

1. Renders every `tests/visual/*_test.gd` at the PR's **merge-base** with `scripts/visual_test.sh`.
   The output is cached with `actions/cache`, keyed by the merge-base SHA, so most runs skip this step.
2. Renders the same at the **PR head**, on the same runner.
3. Diffs captures matched by file name (`<test>/<capture>.png`) with `tools/img_diff.gd`.

Each side runs its own test scripts. A capture that exists only at head is **new**; one that exists
only at base is **removed**. Both are listed in the gallery, and neither one fails the check by itself.

### Diff rule: `tools/img_diff.gd`

Pure GDScript, run with `godot --headless -s`, no new dependencies.

- A pixel is changed when any RGB channel differs by more than **8/255**.
- A capture is changed when more than **0.1 %** of its pixels changed.
- It writes `<capture>.diff.png`: changed pixels in magenta over a dimmed copy of the base.
- Per-capture overrides (threshold, or mask rects for regions that can't be made stable) go in
  `tests/visual/thresholds.cfg`. Each override carries a comment saying why.

### Noise gate (first step of phase 2)

Before the check can block anything, CI renders main **twice** and must report zero changed
captures. **Measured 2026-11-25 (WSL, Xvfb + llvmpipe, main d824841): only 3 of 23 captures pass.**
Several differ across 28–84 % of their pixels. In `scorebug-scrimmage` the HUD matches exactly, but
the game camera is still easing when `capture()` runs, so it sits in a different spot in each run.
Making captures reproducible (#124) is therefore the main work of this step. Fixes, in order of preference:

1. **Settle before capture.** `capture()` snaps camera smoothing and other `1 - exp(-k*dt)` easing
   to its target (or waits a fixed frame count), so the frame no longer depends on how many frames
   ran since setup.
2. `VISUAL_FREEZE=1`, honored by the harness and the game. It pauses shader `TIME`, particles and
   idle animations at a fixed phase.
3. A mask rect in `thresholds.cfg`, with a reason.

The noise job stays report-only until it has run on main for **5 consecutive days** with zero changed captures.

### Scene catalog additions

The 12 existing visual tests already give named captures. Phase 2 adds deterministic captures for
the places past bugs lived and for screens with no capture at all:

| Capture | Why |
|---|---|
| main menu, settings | boot path, brand |
| casual lobby, private lobby | #75 class |
| pause menu | overlay over gameplay |
| Players of the Game | post-game flow |
| game overview / team stats | #115 |
| training hub | separate scene |
| 7v7 pre-snap, each team in possession at each end | #93 |
| Chaosball throw arc near a wall | #110 |

Each one is a `tests/visual/<scenario>_test.gd` that sets up exact state, makes its `check()`
assertions, then calls `capture()`, the same as `scorebug_test.gd`.

### PR output and gate

- **One sticky bot comment** per PR lists only the changed, new and removed captures, as a table:
  base | head | diff. Images go to the existing `pr-evidence/<PR#>` branch, at commit-pinned raw
  URLs. If that push fails (fork PRs have no write token), the comment links the Actions artifact instead.
- **`visual-diff` check:** fails when any capture changed and the PR doesn't carry the `visuals-ok`
  label. A human reviewer adds the label after looking at the gallery. The workflow removes the label
  when a new push changes the set of changed captures, so approval always matches what is on screen.
- A base-side render failure (for example, a visual test broken on main) is reported as a warning,
  with those captures listed as "no baseline". A head-side render failure fails the check.

### Rendered shots for Mac and Windows

`./scripts/remote_shots.sh [--branch <b>] [shot.sh args…]` dispatches a `render-shots` workflow
(`workflow_dispatch`) that runs `scripts/shot.sh` on a Linux runner, waits for it, and downloads the
PNGs with `gh run download` into the job tmp dir. Any agent on any OS can then **look at** its own
visual change before it opens the PR, as `AGENTS.md` already requires. Linux and WSL keep using `shot.sh` directly.

## Team workflow changes

These are doc changes that ship with the phase that needs them:

- `AGENTS.md`, `docs/workflow.md`: "the owner reviews and merges" becomes "a human maintainer
  reviews and merges". Agents still never merge.
- `AGENTS.md` → Opening pull requests: explain any golden or visual diff under Testing. Never
  hand-edit `.golden.txt`. Mac and Windows agents use `remote_shots.sh`.
- `docs/TESTING.md`: `golden.sh`, `img_diff.gd`, `VISUAL_FREEZE`, `thresholds.cfg`, `remote_shots.sh`.
- Branch protection: once the noise gate has had 5 quiet days, a maintainer makes `test` (which runs
  `check.sh`) and `visual-diff` required checks on `main`. A human makes that repo-settings change.

## Rollout

| PR | Contents | Usable alone? |
|---|---|---|
| 1 | Phase 1 complete: situation table and runner, long games with `stat_ranges.cfg`, invariants, `golden.sh`, `check.sh` hook, PR template, TESTING.md | yes: gameplay drift is caught |
| 2 | `img_diff.gd`, `VISUAL_FREEZE`, report-only "render main twice" noise job | yes: shows which scenes are unstable |
| 3 | Render-both-sides with cached base, sticky gallery, `visual-diff` check and `visuals-ok` label, `remote_shots.sh` | yes: the visual gate |
| 4+ | Catalog scenes, split by area so the three developers can do them in parallel | each scene stands alone |

## Proving the gates (plant the bug, per `AGENTS.md`)

Each PR shows its gate going red on a planted bug, then reverts the plant:

| Plant | Expected |
|---|---|
| Shorten the Mesh routes | only `7v7 MESH` and `3v3 MESH` lines change, and the `GOLDEN:` summary names them |
| Halve sack likelihood | a long game's `sacks` goes out of range, and no exact lines are needed to catch it |
| Make a touchdown award 7 points in the sim | the score invariant fires, naming the situation or game, the tick and the play |
| Move a scorebug label 20 px | `visual-diff` flags `scorebug_test/*` and nothing else |
| Render main twice | zero changed captures |

## Open risks

- **Rendering determinism.** It is measured, not hypothetical: 20 of 23 captures are unstable today
  (#124). Phase 2 blocks nothing until the noise gate is clean.
- **Global tuning changes.** Player speed or tackle tuning moves many situation lines at once. The
  `GOLDEN:` summary and the stat ranges are the review. The lines are there to find out *where*,
  not to be read one by one.
- **Cache key correctness.** A stale base render would hide or fake diffs. Key on the full
  merge-base SHA plus a hash of `scripts/visual_test.sh` and `tests/visual/harness.gd`.
