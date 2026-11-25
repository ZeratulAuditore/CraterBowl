# Daily Iteration Loop: Procedure

Each run is one iteration. Each iteration builds on the last. **Tackle exactly one thing.**

## Steps
1. **Orient.** Read `PLAN.md`, `FEATURES.md`, the last 3 entries of `ITERATIONS.md`, and `git log --oneline -10`. Run `./scripts/test.sh` first. If it's red, this iteration's one thing is fixing it (log it under "Discovered").
2. **Pick.** The first unchecked item in "Discovered", otherwise the first unchecked item in Phase A (then Phase B). Number the iteration `NNN` = last + 1.
3. **Brainstorm.** Write `docs/iterations/NNN-<slug>.md` with:
   - Goal (1–2 sentences) and how Gridiron does it (genre mechanic only).
   - 2–3 design options, the pick, and why. Note one way to make it *better* than Gridiron.
   - Acceptance criteria written as testable statements.
4. **Build.** Smallest complete version that meets the criteria.
   - Game rules/physics math go in `src/sim/` as plain `RefCounted` scripts (no Node/scene deps, deterministic, input-driven). This keeps them unit-testable and ready for server authority.
   - Scenes/visuals/input in `src/game/` + `scenes/`. Presentation reads sim state; it never owns rules.
   - Feel numbers go in `src/sim/tuning.gd` constants.
   - Scripted multi-line edits must use `tools/patch.py` `sub()` (fails loudly when a pattern doesn't match). Plain `str.replace` silently no-ops; that hid a stale key handler from iter 010 to 017.
   - Player-facing input must be tested through the real handler (`_key()` in game_flow.gd), not only by calling `do_action()` directly.
   - Use only original or CC0 assets. Never use Gridiron's name, art, UI or audio.
   - Performance: follow `docs/optimization/README.md`. Visible motion is interpolated in `_process`, not set in `_physics_process`. No default-tessellation meshes, no per-frame text rebuilds or allocations, `cast_shadow` off for small or flat things. New expensive effects go behind `src/game/art/quality.gd`.
5. **Test.** Add `tests/test_<area>.gd` covering every acceptance criterion. The gate is **`./scripts/check.sh`** (lint + unit + perf + smoke, about 4 min); it must end `CHECK PASS`. It runs:
   - `./scripts/test.sh`: all unit tests must pass (previous iterations' tests included).
   - `./scripts/smoke.sh`: main scene boots headless for ~300 frames with zero script errors, then `tests/game_flow.gd` drives the real scene through a scripted play. **Extend game_flow.gd with a step for each new player-facing feature.**
   - `./scripts/mm_test.sh` (also run by smoke.sh): matchmaker + 2 queued clients → hosted match starts.
   - `./scripts/net_test.sh` (also run by smoke.sh): headless host + client over localhost. Extend `tests/net_client.gd` when a feature changes networked behavior.
   - `./scripts/shot.sh` for any visual change (art, HUD, camera, effects): renders the real scene offscreen (Xvfb + software GL) to PNGs. **View the PNGs before calling it done.** See `docs/TESTING.md`.
   - `./scripts/perf.sh` (in check.sh): render budget plus CPU medians. If you made something cheaper, lower its budget (ratchet); if you must raise one, log why in `docs/optimization/LOG.md`.
   Iterate until check.sh passes. Do not weaken or delete older tests to go green. **Never launch a windowed game** (`godot --path .`) to check your work; it opens on the user's desktop. Everything in `docs/TESTING.md` runs offscreen.
6. **Record.** Check off the item in `FEATURES.md` and add any follow-ups under "Discovered". Update the docs that own what you changed (`docs/README.md` says which: testing → `docs/TESTING.md`, perf → `docs/optimization/`), in the same commit. Append to `ITERATIONS.md`: number, item, what was built, test counts, known gaps.
7. **Commit** locally on `main`: `iter NNN: <item>`. Never push or publish. **Stage explicit paths only** (`git add <files you changed>`), never `git add -A`: parallel sessions share this worktree, and `-A` once swept another session's uncommitted files into iter 027. Check `git show --stat` before moving on.
8. **Report.** Summarize what shipped, the test results, and what's next, ending with a `result:` line.

## Guardrails
- One item per iteration. If an item is too big, split it in `FEATURES.md` and do the first half.
- If blocked (missing tool, design decision only the user can make), record it in `ITERATIONS.md` and report `needs input:`. Don't guess on irreversible things.
- Keep the game runnable: `godot --path . ` opens to a playable scene after every iteration. Verify that with `./scripts/smoke.sh` + `./scripts/shot.sh`, not by opening a window.
