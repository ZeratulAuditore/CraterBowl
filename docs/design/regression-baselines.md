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

1. **Sim goldens.** Seeded all-bot matches write per-play outcome traces that are committed in the
   repo. They run headless on any OS in seconds.
2. **Visual goldens.** CI renders every visual capture at the PR's merge-base and at the PR head, in
   the same job, and diffs them. No baseline PNGs are stored.

Both depend on a property the repo already enforces: `src/sim` has no engine, time or random calls
(lint rule), rolls are derived from the play situation (`World` "deterministic pseudo-random roll"),
the coin toss comes from a seed, and `tests/test_determinism.gd` proves two bot games are bit-identical.

## Phase 1: sim goldens

### Scenarios

`tests/golden/<scenario>.gd`, each a seeded all-bot run built from the same loop as
`test_determinism.gd` (World + Roster + Match + AI, `dt = 1/60`, `next_play()` 0.5 s after the whistle).

| Scenario | Covers |
|---|---|
| `7v7_full_half` | core offense, defense, downs, spotting, scoring |
| `3v3` | small-size rosters and formations |
| `chaosball` | Chaosball ruleset and scoring |
| `kickoff_and_return` | kicks, returns, touchbacks, onside |
| `two_minute_drill` | game clock, play clock, timeouts, clock stoppage |
| `red_zone` | goal-line spotting, touchdowns, field goals |

Total run time budget: **≤ 30 s** for all scenarios on the WSL box, so the suite can sit in `check.sh --fast`.

### Trace format

`tests/golden/<scenario>.golden.txt`, one line per play, chosen to read well in a diff:

```
P014 H1 08:41  HEL 2&6 @HEL34  pass deep_cross  → INT @NEB41 ret 12  | clock -0:07
```

Fields: play number, period and clock at the snap, offense, down and distance, line of scrimmage,
play family and play name, result (type, spot, yards, return yards, points), and clock used.

The file ends with a summary block: final score and the **stat envelope** (completion %, yards per
play, sacks, turnovers, average air yards, plays per half), rounded to 1 decimal place.

**Positions and velocities are excluded on purpose.** They change with every movement tweak and
would turn the file into noise. The trace records outcomes a player would notice.
`test_determinism.gd` stays the bit-level guard.

### Tick invariants

The scenario runner asserts these every tick. A breach fails immediately with the scenario, tick
and play number:

- No NaN or infinite positions or velocities. No athlete or ball outside the world bounds.
- The ball is in exactly one state: held by one athlete, in flight, or dead.
- The score changes only on the tick of a scoring event, by that event's points.
- Down is 1–4, distance > 0, and the line of scrimmage is on the field.

### Commands and workflow

| Command | Does |
|---|---|
| `./scripts/golden.sh` | Runs every scenario, diffs each trace against its committed `.golden.txt`, prints a unified diff, and exits 1 on any difference or invariant breach |
| `./scripts/golden.sh --update` | Rewrites the `.golden.txt` files from the current code |
| `./scripts/golden.sh <scenario>` | Runs one scenario |

- `golden.sh` joins the `unit` tier of `check.sh`, which `--fast` also runs, so the pre-commit path and CI both run it.
- A PR that changes gameplay commits the regenerated `.golden.txt` files and explains the diff under
  `### Testing` → "Golden diff". `.github/pull_request_template.md` gets that prompt.
- **Never hand-edit a `.golden.txt`.** When two PRs both move a trace, the second one merges
  `origin/main`, and resolves any `.golden.txt` conflict by running `--update` (it overwrites the
  conflicted file from the merged code) and committing the result. The `unit` tier fails when
  regenerated output differs from the committed file, so a skipped or botched `--update` can't land.
  (No custom `.gitattributes` merge driver: those need per-clone git config the other developers
  wouldn't have.)

### Failure handling

- A scenario that crashes, or runs past its 60 s timeout, fails with its log and the last play number.
- A missing `.golden.txt` fails with "no baseline: run `./scripts/golden.sh --update`". A new
  scenario lands together with its baseline.

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
captures. A capture that flickers gets one of these, in order of preference:

1. `VISUAL_FREEZE=1`, honored by the harness and the game. It pauses shader `TIME`, particles and
   idle animations at a fixed phase.
2. A mask rect in `thresholds.cfg`, with a reason.

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
| 1 | Phase 1 complete: runner, 6 scenarios, invariants, `golden.sh`, `check.sh` hook, PR template, TESTING.md | yes: gameplay drift is caught |
| 2 | `img_diff.gd`, `VISUAL_FREEZE`, report-only "render main twice" noise job | yes: shows which scenes are unstable |
| 3 | Render-both-sides with cached base, sticky gallery, `visual-diff` check and `visuals-ok` label, `remote_shots.sh` | yes: the visual gate |
| 4+ | Catalog scenes, split by area so the three developers can do them in parallel | each scene stands alone |

## Proving the gates (plant the bug, per `AGENTS.md`)

Each PR shows its gate going red on a planted bug, then reverts the plant:

| Plant | Expected |
|---|---|
| Change one constant in `src/sim/tuning.gd` | `golden.sh` fails with a readable per-play diff |
| Make a touchdown award 7 points in the sim | the score invariant fires with scenario, tick and play |
| Move a scorebug label 20 px | `visual-diff` flags `scorebug_test/*` and nothing else |
| Render main twice | zero changed captures |

## Open risks

- **Rendering determinism under llvmpipe.** Shader `TIME`, particles and skinned idle poses may not
  be frame-stable. The noise gate (above) measures this before anything blocks.
- **Golden churn on tuning-heavy weeks.** A tuning PR rewrites several traces at once. That diff is
  the review, but if it gets too long to read, summarize it with the stat envelope first and the per-play lines second.
- **Cache key correctness.** A stale base render would hide or fake diffs. Key on the full
  merge-base SHA plus a hash of `scripts/visual_test.sh` and `tests/visual/harness.gd`.
