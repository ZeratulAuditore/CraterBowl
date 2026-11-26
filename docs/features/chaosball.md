# Chaosball

Feature-level doc: how this works for players **today** on `main`. Open work: GitHub issues labelled `area:chaosball`.

## Summary
Chaosball is a 3v3 alternate ruleset: low gravity, anyone can throw from anywhere any number of times,
the ball bounces off the turf and arena walls, and each possession is a single live play. Touchdowns are
worth more the more teammate passes you complete, and holding the ball too long makes it explode.

## How it plays

### Getting a game
- Always 3v3 (60 × 30 field, see [rules.md](rules.md)).
  Picking Chaosball forces size 3 in the menu/CLI (`--mode=chaosball`), the private lobby (host key M) and the matchmaker.
  On the Online and VS Bots screens the Size row then shows a dimmed 3v3 and can't be changed; switching back to Classic restores the earlier size pick (#83).
- Queues: casual or competitive with `game = chaosball`; Chaosball and classic entries never match together.
- HUD: `CHAOSBALL 3v3`, plus `STREAK n -> TD v | BALL t s`; the scorebug shows `STREAK n · TD v`.

### Rules that differ from classic (`World.set_ruleset("chaosball")`)
| Rule | Value |
|---|---|
| Gravity | 0.45× (`CHAOS_GRAVITY_SCALE`); the aim solver and arc preview use it, so aim stays exact |
| Who can throw | any ball holder, anywhere on the field, unlimited passes per play |
| Self-catch | allowed (lob ahead and run under it); a pass must travel 2.5 yd first (`MIN_PASS_TRAVEL`) |
| Catching | nearest standing player within `CATCH_RADIUS` (1.2 yd) catches; no breakups |
| Opponent catch | interception: possession swings and the play stays live |
| Bounces | ground and wall hits each count; the ball is catchable between bounces; the 3rd kills it (`CHAOS_MAX_BOUNCES`, restitution `BOUNCE_RESTITUTION` 0.55 vertical, `BOUNCE_FRICTION` 0.8 horizontal) |
| Walls | sidelines and back lines of the end zones reflect a thrown ball |
| Handoffs, run plays, defensive calls | disabled |

Throws use the normal controls: J or left click to pass, hold Ctrl while releasing for a lob (`LOB_ANGLE` 65°).
Lobs matter here because a flat pass outruns a sprinter, so self-catches need the arc.

### Possession flow (`Match._chaos_next`)
- One live play per possession. A touchdown scores and the other team receives at its own 15 (25% of the field).
- Any other end (tackle, out of bounds, incompletion, explosion) is a **turnover at the spot** to the team that
  did not end the play with the ball. There are no downs and no tries.
- The clock runs only during live plays (never between plays). Halves, the one-minute warning and timeouts
  (2 per half in 3v3) work as in classic.

### Pass streak and touchdown value
- `streak` +1 for each completed catch by a **teammate** of the thrower. Self-catches don't count.
- An interception resets it to 0 for the new team; it also resets every possession.
- Touchdown value = min(`STREAK_BASE_POINTS` 2 + streak, `STREAK_MAX_POINTS` 7): a solo run is 2, five completions reach 7.

### Pass clock
- While anyone holds the ball during a live play, `hold_t` counts up; every catch resets it.
- At `PASS_CLOCK` (5.0 s) the ball explodes: dead ball, carrier knocked down, turnover at the spot ("BALL EXPLODED" banner).

## Design decisions
- The ruleset lives on `World` as a small rules dictionary, so classic and Chaosball share one sim.
- Self-catches don't add to the streak; otherwise lobbing to yourself would farm points.
- The pass clock punishes ball-hogging and pushes teams into the streak mechanic.

## Code and tests
- `src/sim/world.gd` — `set_ruleset`, `gravity()`, `_wall_bounce`, `_try_catch_chaos`, `streak_points`, `_step_pass_clock`.
- `src/sim/match.gd` — `_chaos_next` (TD/turnover flow); no running clock between plays.
- `src/sim/passing.gd` — gravity-aware solver and lob arc.
- `src/sim/ai.gd` — `_chaos_pass` (see [bots.md](bots.md)).
- `src/net/lobby.gd`, `src/net/matchmaker.gd` — mode setting, 3v3 forcing, separate queues.
- `src/game/main.gd`, `src/game/overlay.gd` — HUD streak/pass clock text, explosion banner.
- Tests: `tests/test_chaosball.gd`, `tests/test_chaos_scoring.gd`, `tests/test_matchmaker.gd`
  (`test_chaosball_queue_separate_and_3v3`), `tests/game_flow.gd`, `scripts/mm_test.sh`.

## Open issues
- None open with a Chaosball-specific scope.
