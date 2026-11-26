# Bots

Feature-level doc: how this works for players **today** on `main`. Open work: GitHub issues labelled `area:bots` (listed below).

## Summary
Every athlete without a human owner is a bot, in every mode: offline vs bots, private matches, queues,
Chaosball and the scrimmage drill. Bots follow the same rules as humans (no extra speed, same fumble and
catch rules). There is one difficulty level. A player who disconnects frees their slot and a bot takes over.

## How it plays

### Who is a bot
- Slots are filled by humans first (`Roster.auto_assign`: the team with fewer humans, best free slot in
  priority order QB/LB, WR/CB, WR/CB, RB/S, C/DL, OL/DL, OL/S). Every unowned slot is driven by `src/sim/ai.gd`.
- Online, the host runs all bots. On disconnect the host releases the slot and the bot resumes control.

### Pre-snap and play calling
- Bots don't move pre-snap; bot defenders stay set (they never break stance).
- When **no human is on offense**, the bot QB calls a play and snaps:
  - after `AI_SNAP_DELAY` (2.5 s), or `HUDDLE_SECONDS` (5.0 s) in a classic match that has a human, so humans can see the call.
  - The 20 s play clock still auto-snaps for a human offense that doesn't.
- `AI.choose_play(down, distance, variant, can_run)` rotates through fitting plays so drives don't repeat:

| Situation | Options |
|---|---|
| RB on the field, down ≤ 2, distance ≤ 10, every 3rd call | Inside Zone / Outside Sweep alternating (sweep is always flipped) |
| distance ≥ 12 | Deep Shot, Verticals, Flood |
| distance ≤ 3 | Slants, Curls, Mesh |
| 3rd/4th down | Flood, Mesh, Slants, Deep Shot |
| otherwise | Curls, Mesh, Slants, Verticals, Flood |

- With a human on offense, bots don't call; the play defaults to Slants (≤ 3 to go), Deep Shot (≥ 15 to go and ≥ 25 yd from goal) or Mesh.
- Defensive calls are suggested for every defense (bot or human) by `DefensivePlaybook.suggest`: Goal Line Zone within
  `DEFENSE_GOAL_LINE_RANGE` (5 yd) of the goal, Deep Zone on 3rd/4th with ≥ 15 to go and ≤ 60 s left in the half, else Cover 2.
- Bots never call timeouts, never choose the 2-point try, and never use spin or dash.

### Offense
- **QB (pass):** drifts away from the nearest rusher inside 4 yd, never past the line. Throws after a read time of
  about 1.6–2.6 s (`AI_QB_THROW_TIME` with per-play variation), or earlier when a defender is within `AI_QB_PRESSURE` (3 yd).
  Picks the receiver past the line with the best separation + depth (`AI_QB_DEPTH_WEIGHT`), waits for
  `AI_QB_MIN_SEPARATION` (1.5 yd) unless pressured or past `AI_QB_MAX_HOLD` (3.2 s), and leads him along his route
  at `AI_QB_PASS_POWER` (0.65), never toward the sideline.
- **QB (run call):** hands off to the RB within `AI_HANDOFF_WINDOW` (1.5 s); linemen block toward the called lane.
- **Receivers:** run their route paths, steer around a defender in the lane, settle at the end of comeback routes.
- **Linemen:** pass-protect against the nearest free rusher within `PROTECTION_RANGE` (8 yd).
- **Ball carrier:** runs for the end zone, jukes defenders in a 5-yd lane, stays 2 yd off the sideline, and doesn't
  sprint while any opponent is within `AI_PROTECT_BALL_RANGE` (4 yd) (fumble ball security).
- **Teammates of the carrier** move between him and the nearest pursuer; blocks form on contact.

### Defense
- **DL** always rushes the carrier. Blitz calls add the LB.
- **Man (Cover 1, Goal Line Man, Deep Man):** at the snap each receiver gets the nearest free CB/S (LBs only take backs).
  Defenders trail with a reaction lag (`AI_COVER_REACTION` 0.25 s, `AI_COVER_TRAIL` 0.8 yd) and hold level/inside until the receiver passes them.
- **Zone calls:** defenders hold a landmark (`DEFENSE_UNDER_DEPTH` 8, `DEFENSE_DEEP_DEPTH` 18, `DEFENSE_PREVENT_DEPTH` 25, `DEFENSE_GOAL_DEPTH` 4 yd).
- With no call (Chaosball): man coverage where possible; an unassigned LB spies the QB 6 yd off (`AI_SPY_DEPTH`) and blitzes
  at `AI_SPY_BLITZ_TIME` (3.5 s) or when the QB crosses the line; others sit deep (`AI_DEEP_ZONE` 14 yd).
- **Ball in the air:** the 2 nearest players per side break to the predicted landing point; man defenders play the receiver's hands, not the ball.
- **Tackling:** pursuers lead the carrier and dive within `AI_DIVE_RANGE` (2 yd). Everyone chases a loose ball.

### Chaosball
- A carrier passes to the most open teammate when an opponent is within `AI_CHAOS_PRESSURE` (3.5 yd) or the pass clock
  has less than `AI_PASS_CLOCK_MARGIN` (1.2 s) left. See [chaosball.md](chaosball.md).

## Design decisions
- Bots obey the same skill rules as humans (no-sprint ball security), so they model good habits.
- The QB leads receivers along their route; a linear lead threw curls and outs to empty grass.
- Bot simulations found rule bugs: rushers batted every throw at release (fixed with `MIN_PASS_TRAVEL`), interceptions
  were too easy (now `INT_RADIUS` at closest approach), and man defenders walked through unreleased receivers.
- Play choice is deterministic (rotating `variant`), so bot games are reproducible.
- Known weakness from iteration 015: deep passing is easy against bots; zone calls (030–032) were added partly for this.

## Code and tests
- `src/sim/ai.gd` — all bot inputs, play calling, QB reads, coverage, pursuit.
- `src/sim/defensive_playbook.gd` — call catalog and `suggest`.
- `src/sim/world.gd` — `man_assignments`, `defense_assignment`, `protection_target`, `run_block_assignments`.
- `src/sim/roster.gd` — slot ownership; `src/game/main.gd` — `_step_authoritative` (snap delay, AI tick).
- `tools/bot_stats.gd`, `tools/play_stats.gd` — all-bot outcome stats.
- Tests: `tests/test_bots.gd` (incl. a full all-bot game), `tests/test_defensive_playbook.gd`, `tests/test_run_game.gd`,
  `tests/test_chaos_scoring.gd` (`test_ai_passes_before_clock`), `tests/test_match_sizes.gd` (3v3/5v5 bot games).

## History
- 015 [Bots](../iterations/015-bots.md)
- 030 [Defensive playbook](../iterations/030-defensive-playbook.md)
- 031 [Defensive selection](../iterations/031-defensive-selection.md)
- 032 [Defensive assignments and huddle](../iterations/032-defensive-huddle.md)
- 033 [Run game](../iterations/033-run-game.md)

## Open issues
- #14 C32 Co-op vs bots playlist + bot difficulty
