# Kicking

Feature-level doc: how this works for players **today** on `main`. Layering: `../design/architecture.md`. Open work: GitHub issues labelled `area:kicking` (listed below).

## Summary
Every classic match opens with a coin toss. Kickoffs are live plays with coverage and returns. Any scrimmage down can be turned into a punt or a field-goal try, and the 1-point try is a PAT kick. Kicks aim like passes (aim point + throw meter). Rushers can block a kick early in its flight, and the ball is then live. Shipped in iter 035 (#2, #3). Chaosball has no kicking (`call_kick` refuses in chaos).

## How it plays
| Situation | What happens |
|---|---|
| Coin toss | Deterministic from a seed (`--toss=N`). The winner has 5 s to press **1** (receive) or **2** (kick). Bots, or no answer, choose receive. The other team receives the second half. |
| Kickoff | From your own 35 (`KICKOFF_SPOT_FRACTION`), or the 20 after a safety. The kicker is on the tee, coverage spreads out, and the receivers form a front row plus two deep returners. **Space** or the play clock gives a default kick (`KICKOFF_DEFAULT_POWER` 0.85). **J**/LMB gives an aimed kick with the throw meter and an arc preview. |
| Kickoff results | Return, touchback → own 25 (`KICKOFF_FRACTION`), out of bounds → own 40 (`KICKOFF_OOB_FRACTION`), or a rolled/downed spot. An unfielded ball that stops for `KICK_REST_TIME` is downed. |
| Onside | Recovery past `ONSIDE_MIN_TRAVEL` (10 yd) exists as the `world.onside` mutator, **off by default**. Turning it on belongs to #42. |
| Punt | **K** cycles the kick call on any scrimmage down. The punter lines up `PUNT_DEPTH` 10 yd deep and the returner drops `PUNT_RETURNER_DEPTH` 38 yd past the LOS. A touchback comes out to the 20 (`PUNT_TOUCHBACK_FRACTION`). Fake punts play a normal down. |
| Field goal | **K K**. The holder sets up `FG_HOLD_DEPTH` 7 yd deep. Good = between the uprights and above the 3.3 yd crossbar at the end line. A miss gives the defense the ball at the kick spot, or at its 20 if that's further out. |
| Tries | 1 point = PAT kick from the 15. 2 points = a scrimmage play from the 10. |
| Blocks | A rusher within `KICK_BLOCK_REACH` (1 yd) of the ball during its first `KICK_BLOCK_WINDOW` (5 yd) blocks it. The ball pops up live (scoop and score). If the kicking team recovers, it plays the down out. |
| Bots | 4th-down rule: try a FG within `AI_FG_MAX` (50 yd); go for it on 4th & ≤2 past midfield; otherwise punt. They always kick the PAT (#69), vary kickoff depth, cover in lanes, and set a return wall. |

Kick flight is a ballistic solve: `world.kick_velocity(kind, from, target, power)`. Speed runs from `KICK_SPEED_MIN` 14 to `KICK_SPEED_MAX` 27 yd/s, and the launch angle depends on the kick (`KICK_ANGLE`: punt 52°, FG 38°, kickoff 42°).

## Design decisions
- **Kicks reuse the passing aim.** The same aim point and meter means there's no extra control to learn (pillar 3).
- **Onside is a mutator, off by default.** Gridiron removed onside kicks, and backyard rules (#42) own turning it on.
- **The online path:** `kick`, `kick_call` and `toss` actions are sanitized and routed through the host. Snapshots carry the kick call, the kicked flag and the toss winner. The huddle is skipped on kickoffs.
- **Tests that assumed the old automatic touchback** were changed to expect live kickoffs. `game_flow` resets to a scrimmage for its legacy steps (`opening_kickoff`), and `net_test`'s host runs `--no-kickoff`.

## Code and tests
- `src/sim/world.gd`: `call_kick`, `setup_kickoff`, `kick`, `kick_velocity`, block and rest rules
- `src/sim/match.gd`: toss, `_kickoff`, kick outcomes and spots
- `src/sim/tuning.gd`: `KICK_*`, `PUNT_*`, `FG_*`, `ONSIDE_*`, `AI_FG_MAX`
- `src/sim/ai.gd`: `_kick_protect`, `_bot_kick`, `_kick_coverage`, the 4th-down rule
- `src/game/main.gd`: K / 1 / 2 handling and the kick meter
- Tests:
  - `tests/test_kicking.gd`: about 30 tests, including a full bot match with kicks
  - `tests/game_flow.gd`: toss, metered kickoff + arc + return, K punt, K K field goal
  - The scoring, clock and match-size tests expect live kickoffs

## History
- 008 [Scoring](../iterations/008-scoring.md): the old automatic kickoff/touchback
- 035 B09 + C02 Kicking game: `../../ITERATIONS.md` (branch `kicking-game`, #2, #3)

## Open issues
- #67 D06 Kicking stats: FG made/att + long, punt avg, kick/punt return yards
- #68 D07 Kick meter art: stepped power meter beside the kicker + ball on a tee
- #69 D08 Fair catch + bot 2-pt decisions
- #42 C27 Backyard rules / trick plays (onside kick mutator)
