# Crater Bowl (repo: football-game): agent guide

Godot 4.3 arcade online football. This file is the entry point for any agent, human or
looped. It's short on purpose: each section links to the doc that owns the details (`docs/README.md`).

| Need | Read |
|---|---|
| Iteration procedure (orient → pick → design → build → check → record → commit) | `LOOP.md` |
| Vision, backlog, history | `PLAN.md`, `FEATURES.md`, `ITERATIONS.md`, `docs/gaps/` |
| How to test anything without a window | `docs/TESTING.md` |
| Performance rules, budgets, measuring | `docs/optimization/README.md`, `docs/optimization/LOG.md` |
| Menus, brand, distribution | `OUT_OF_GAME.md` |

### Committing: commit everything, by default
When you finish a task (or a loop iteration), commit **everything** in the working tree without
asking: `git add -A && git commit`. That includes files other parallel sessions changed. The owner
wants the tree clean and every change in history rather than work-in-progress left lying around.
- Commit to the current branch (normally `main`). Don't push or publish unless asked.
- Never `git stash`, reset or checkout files to isolate your changes. Other sessions share this
  worktree and that discards or tangles their work.
- Write the message about your change, and add a line listing other sessions' files that rode
  along (`Also includes in-progress work: src/net/..., ...`). Check `git show --stat` afterwards.
- Never commit secrets (`.env`, keys, credentials). `.gitignore` covers build output and `user://` data.

Code map: `src/sim/` = rules (pure, deterministic, unit-tested), `src/game/` = presentation (views,
camera, HUD, art in `src/game/art/`), `src/net/` = netcode, `src/ui/` = menus/settings,
`tests/` = tests and harnesses, `tools/` = dev/diagnosis scripts, `scripts/` = the commands below.

### Building your own loop

Every unit of work, whether a loop iteration, a bug fix or a perf pass, has the same shape:

1. **Orient.** `git log --oneline -10`, the backlog, and `./scripts/check.sh --fast`. If it's red, fixing it is the job.
2. **Define done first.** Write acceptance criteria as testable statements (`docs/iterations/NNN-*.md` for loop items).
3. **Smallest complete change.** One item per loop. Rules in `src/sim`, visuals in `src/game`.
4. **Gate.** `./scripts/check.sh` must print `CHECK PASS`. Add tests for every criterion *before* calling it done.
5. **Look** at visual changes with `./scripts/shot.sh` and actually view the PNGs.
6. **Record.** Docs that own what you changed (below), `ITERATIONS.md`, and the backlog.
7. **Commit everything** (`git add -A`, see Committing below), then check `git show --stat`.

A loop that can't measure its own success isn't done. If an item has no test, perf number or
screenshot proving it, add one.

### Testing

**Never open a game window** (`godot --path .`, `godot -e`). In WSL it pops up on the user's
desktop, and five sessions share this machine. Everything below runs offscreen and parallel-safe.
Full guide: `docs/TESTING.md`.

| Command | What | Time |
|---|---|---|
| `./scripts/check.sh` | **the gate**: lint + unit + perf + smoke, fail-fast | 3–4 min |
| `./scripts/check.sh --fast` | lint + unit + perf (the pre-commit hook) | about 45 s |
| `./scripts/test.sh` | unit tests `tests/test_*.gd` (incl. determinism) | about 10 s |
| `./scripts/smoke.sh` | headless boot + `game_flow.gd` + `menu_flow.gd` + net + matchmaking | 2–3 min |
| `./scripts/shot.sh --frames=60,200 --snap=100` | real-renderer PNGs via Xvfb. **View them.** | about 30 s |

- New player-facing behavior gets a step in `tests/game_flow.gd`, driven through the real input
  handler (`_key()`). New networked behavior extends `tests/net_client.gd`.
- A new check must go red when you plant the bug it's meant to catch. Try it once.
- Don't weaken or delete older tests to go green. `check.sh` isolates `user://` (temp
  `XDG_DATA_HOME`), so tests can't touch real saves.
- Run `./scripts/check.sh` before you commit. (A pre-commit hook exists, `scripts/install-hooks.sh`, but it's off by default
  because commit-everything would let other sessions' WIP block your commit. See `docs/TESTING.md`.)

### Optimization

The game must feel smooth: frame-time **p99** over mean FPS. Rules (details and the why:
`docs/optimization/README.md`):

- **Sim at 60 Hz, render at display rate.** Anything visible that moves is interpolated in
  `_process` (`place()`/`interpolate(f)`), never only set in `_physics_process`. Teleports snap.
  Smoothing uses `1 - exp(-k*dt)`.
- **No default-tessellation meshes** (`SphereMesh.new()` ≈ 4k tris). Use `src/game/render_cache.gd`.
  Share meshes and materials.
- **Shadows only from things that need them.** Flat, small, UI-ish and transparent geometry gets `cast_shadow = OFF`.
- **Skinned athletes are the most expensive thing on screen** (about 8 ms each on WSL's GL path). Measure before adding bones, verts or characters.
- **Per-frame work is change-driven.** Text at 10–20 Hz, no mesh rebuilds or shader-param pushes
  when nothing changed, no allocations or `print()` per frame.
- **Expensive effects go behind `src/game/art/quality.gd`** (`--gfx=low|medium|high`).
- `./scripts/perf.sh` enforces budgets (render counts plus CPU medians). Ratchet: lower a budget when you
  make something cheaper; raise one only with a written reason in `docs/optimization/LOG.md`.
- Claim a perf win only with before/after numbers: `./scripts/render_bench.sh`
  (`GPU=1` for the real GPU via d3d12), interleaved runs, `uptime` noted. This WSL box is not
  player hardware; feel on real hardware is the user's call (native Windows build).

### Documenting your work (updating docs/)

`docs/README.md` maps every kind of fact to the one doc that owns it. Rules:

- **Docs ship in the same commit as the change.** A behavior change without its doc update is unfinished.
- Changed how to test? Update `docs/TESTING.md`. Changed perf, budgets or rules? Update `docs/optimization/README.md`,
  and add dated numbers to `docs/optimization/LOG.md`. Loop item? Write `docs/iterations/NNN-*.md`
  plus an `ITERATIONS.md` entry. Found a bug you're not fixing now? Add a `D##` under "Discovered" in `FEATURES.md`.
- One home per fact: link, don't copy. Numbers carry date, machine and mode. Write down what
  **didn't** work; the next agent needs that most.
- If you change a rule here, update the doc it links to as well (and vice versa).

### Parallel sessions and git

Several Claude sessions work on this repo at once (game loop, graphics, out-of-game, perf).

- The `main` checkout at `~/Coding/football-game` belongs to the loop session. Other work uses
  its own worktree (`~/Coding/football-game-<topic>`) on a branch, merges `origin/main` often,
  and lands on `main` only after `check.sh` passes.
- Shared checkouts hold other sessions' uncommitted files; per the Committing rule they ride along in your commit (list them in the message).
- Never `git stash` / `stash pop` bare: the stash is shared across worktrees.
- Claim backlog items in `FEATURES.md` / `docs/gaps/TODO.md` (`[~] owned by ...`) before starting.

### Definition of done
`CHECK PASS`; acceptance criteria covered by tests; visual changes viewed via `shot.sh`;
perf budgets green (ratcheted if you improved them); owning docs updated; everything committed
(Committing rule); report ends with a `result:` line.
