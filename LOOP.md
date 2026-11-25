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
   - Use only original or CC0 assets. Never use Gridiron's name, art, UI or audio.
5. **Test.** Add `tests/test_<area>.gd` covering every acceptance criterion. Then run:
   - `./scripts/test.sh`: all unit tests must pass (previous iterations' tests included).
   - `./scripts/smoke.sh`: main scene boots headless for ~300 frames with zero script errors, then `tests/game_flow.gd` drives the real scene through a scripted play. **Extend game_flow.gd with a step for each new player-facing feature.**
   - `./scripts/net_test.sh` (also run by smoke.sh): headless host + client over localhost. Extend `tests/net_client.gd` when a feature changes networked behavior.
   Iterate until both pass. Do not weaken or delete older tests to go green.
6. **Record.** Check off the item in `FEATURES.md` and add any follow-ups under "Discovered". Append to `ITERATIONS.md`: number, item, what was built, test counts, known gaps.
7. **Commit** locally on `main`: `iter NNN: <item>`. Never push or publish.
8. **Report.** Summarize what shipped, the test results, and what's next, ending with a `result:` line.

## Guardrails
- One item per iteration. If an item is too big, split it in `FEATURES.md` and do the first half.
- If blocked (missing tool, design decision only the user can make), record it in `ITERATIONS.md` and report `needs input:`. Don't guess on irreversible things.
- Keep the game runnable: `godot --path . ` opens to a playable scene after every iteration.
