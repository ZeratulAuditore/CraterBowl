# Training

Training has two entry points: **Main menu → Training**, and the waiting lobby you get automatically
while queued for an online match.

## Training ground (hub)
You free-roam an open field with a ball you can throw around. Three standing portals sit across midfield:

| Portal | Station | What you do |
|---|---|---|
| orange | **Blocking** | You play center. The ball auto-snaps to a bot QB. Keep him clean for the pocket clock (3.0 / 3.4 / 3.8 s). A sack fails the rep. |
| green | **Practice field** | Throw at rings worth 1 / 2 / 3 points (+1 for a bullseye), and run the timed 40-yard dash lane on the right sideline. |
| cyan | **Catching** | Jugs drill. A bot QB throws a new route each rep (slant, curl, out, in, post, corner, go), and a live corner covers you. Race to 15 catches. |

You can leave a station two ways: press **Backspace**, or walk into the small purple portal near the left
sideline. Both take you back to the hub.

## Progression
- **Blocking / catching levels:** every 3-rep streak raises the level, up to 3. A failed rep drops one level.
  - Blocking adds a rusher per level, plus bot linemates at levels 2 and 3. Benched players wait on the sideline.
  - Catching tightens the corner's cushion from 10 yd to 6 yd to press at 2 yd.
- **Personal bests** are saved to `user://training.json` (tests pass `--training-file`). They cover the best
  blocking and catching streaks, the 15-catch race time, the 40-yard dash and practice-field points.
- **Overlay:** the coaching card shows the objective, your current route and your bests. The status line
  shows the snap countdown, the pocket clock and the live dash timer. Banners call out clean pocket, sacks,
  level-ups, target hits and new bests.

## Queue waiting lobby
`--queue=...` (Quick match / Ranked / party / Chaosball) now spawns you on the training ground instead of a
frozen "SEARCHING" screen. The overlay title shows `SEARCHING FOR A CASUAL MATCH 0:42 · <station>`. When the
matchmaker pairs you, `main._end_warmup()` rebuilds the queued match's world, and the normal host/join →
lobby flow continues. Pass `--no-warmup` to get the old behaviour. `scripts/mm_test.sh` asserts that both
queued clients warm up and then leave the training ground when they're matched.

## Code
- `src/sim/drills.gd`: all drill rules (pure). New kinds are `hub`, `blocking`, `field`. `catching` was reworked.
  - Geometry for portals, targets and the dash lane lives here, so sim and art agree.
  - Practice-field targets score where the pass descends through catch height (the aim point), not where
    it bounces.
- `src/game/art/training_art.gd`: portal, target, lane and pocket visuals (view only).
- `src/game/main.gd`: portal switching, Backspace, `override_inputs` (benched bots stand still, the QB
  doesn't scramble), queue warm-up.
- `src/game/overlay.gd`: training title, card, status, hints and banners.
- Tests: `tests/test_training.gd` (unit), `tests/game_flow.gd` steps 7600–8200 (real scene, real keys).
