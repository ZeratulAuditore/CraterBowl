# Training

Feature-level doc: how this works for players **today** on `main`. Open work: GitHub issues labelled `area:training` (listed below).

## Summary
Training is single-player practice against bots. The training ground is a free-roam field with three portals
to skill stations (blocking, practice field, catching), and the classic drills (passing, tackling, scrimmage)
are still available. The training ground also doubles as the waiting lobby while you're queued for an online
match. Practice never runs the game clock and personal bests are saved locally.

## How it plays

### Entry points
- **Main menu → Training** lists Training ground, the three stations, then "Classic drills". CLI: `-- --practice=KIND`
  (`hub`, `blocking`, `field`, `catching`, `passing`, `tackling`, `scrimmage`).
- **Queue waiting lobby:** see below.

### Training ground (hub)
You free-roam an open field with a ball you can throw around (it comes back to you 0.7 s after it lands, `Drills.RESPAWN`).
Three portals stand across midfield:

| Portal | Station | What you do |
|---|---|---|
| orange | **Blocking** | You play center. The ball auto-snaps to a bot QB. Keep him clean for the pocket clock (`POCKET_TIME` 3.0 / 3.4 / 3.8 s by level). A sack fails the rep. |
| green | **Practice field** | Throw at rings worth 1 / 2 / 3 points (+1 inside the `BULLSEYE` 1.2 yd), and run the timed 40-yard dash lane on the right side of the field. |
| cyan | **Catching** | Jugs drill. A bot QB throws a new route each rep (slant, curl, out, in, post, corner, go), and a live corner covers you. Race to 15 catches (`CATCH_RACE`). |

- Blocking and catching snap automatically after `SNAP_DELAY` (1.8 s); Space snaps sooner.
- Leave a station with **Backspace** (offline only) or by walking into the small purple portal near the left sideline. Both return to the hub.

### Classic drills
| Drill | Setup | Success |
|---|---|---|
| Passing | you are the QB with WR, WR, RB and no defense; each rep cycles the playbook | a catch |
| Tackling | you are the LB; a bot RB starts live 12 yd away | a tackle (or forced fumble); TD, out of bounds or 6 s (`TACKLE_TIMEOUT`) fails |
| Scrimmage | full 7v7 vs bots, normal downs | no scoring; no clock |

Reps pause `REP_PAUSE` (1.2 s) after the result, then reset at the drill line (`Drills.LOS`, own 30). Timeouts (T) are ignored in practice.

### Progression
- **Blocking / catching levels:** every 3-rep streak raises the level (`LEVEL_EVERY`), up to 3 (`MAX_LEVEL`). A failed rep drops one level.
  - Blocking adds a rusher per level, plus bot linemates (one at level 2, two at level 3). Benched players wait on the sideline.
  - Catching tightens the corner's cushion (`CB_CUSHION`) from 10 yd to 6 yd to press at 2 yd.
- **Personal bests** are saved to `user://training.json` (tests pass `--training-file`): best blocking and catching
  streaks, the 15-catch race time, the 40-yard dash and practice-field points.
- **Overlay:** the coaching card shows the objective, your current route and your bests. The status line shows the snap
  countdown, the pocket clock and the live dash timer. Banners call out clean pocket, sacks, level-ups, target hits and new bests.

### Queue waiting lobby
`--queue=...` (Quick match / Ranked / party / Chaosball) spawns you on the training ground instead of a frozen
"SEARCHING" screen. The overlay title reads `SEARCHING FOR A CASUAL MATCH  0:42  ·  <station>`. When the matchmaker
pairs you, `main._end_warmup()` rebuilds the queued match's world and the normal host/join → lobby flow continues.
`--no-warmup` restores the old behaviour.

## Design decisions
- Each drill builds only the athletes it needs into a fresh World, instead of threading "inactive athlete" flags through the sim.
- Practice-field targets score where the pass descends through catch height (the aim point), not where it bounces.
- Portal, target and dash-lane geometry lives in `drills.gd` so sim and art agree.
- Queue waiting reuses the training ground so players warm up instead of watching a timer.

## Code and tests
- `src/sim/drills.gd` — all drill rules (pure), station geometry, levels, bests persistence, HUD/card text.
- `src/game/art/training_art.gd` — portal, target, lane and pocket visuals (view only).
- `src/game/main.gd` — `start_practice`, portal switching, Backspace, `override_inputs` hook (benched bots stand still,
  the blocking QB doesn't scramble), queue warm-up (`_end_warmup`).
- `src/game/overlay.gd` — training title, card, status, hints and banners. `src/ui/main_menu.gd` — Training screen.
- Tests: `tests/test_training.gd` and `tests/test_drills.gd` (unit); `tests/game_flow.gd` steps 4700–5300 (classic drills)
  and 8600–9200 (training ground, real keys); `scripts/mm_test.sh` asserts both queued clients warm up and leave the training ground when matched.

## Open issues
- #23 C17 1v1 Catching mode
- #24 C18 Guided tutorial
