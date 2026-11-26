# Kicking

Feature-level doc: how this works for players **today** on `main`. Layering: `../design/architecture.md`. Open work: GitHub issues labelled `area:kicking` (listed below).

## Summary
Every classic match opens with a coin toss. Kickoffs are live plays with coverage and returns. Any scrimmage down can be turned into a punt or a field-goal try, and the 1-point try is a PAT kick. Aim at a point on the field and press **J** or LMB to kick immediately. The distance to the aim point determines the power. Rushers can block a kick early in its flight, and the ball is then live (#2, #3). Chaosball has no kicking (`call_kick` refuses in chaos).

## How it plays
| Situation | What happens |
|---|---|
| Coin toss | Deterministic from a seed (`--toss=N`). The winner has 5 s to press **1** (receive) or **2** (kick). Bots, or no answer, choose receive. The other team receives the second half. |
| Kickoff | From your own 35 (`KICKOFF_SPOT_FRACTION`), or the 20 after a safety. The kicker is on the tee, coverage spreads out, and the receivers form a front row plus two deep returners (`KICKOFF_RETURNER_DEPTH`, their own 10). **Space** or the play clock gives a default kick (`KICKOFF_DEFAULT_POWER` 0.85). **J**/LMB fires an aimed kick on press. The arc previews the kick before you fire. |
| Kickoff results | Return, touchback → own 25 (`KICKOFF_FRACTION`), out of bounds → own 40 (`KICKOFF_OOB_FRACTION`), or a rolled/downed spot. An unfielded ball that stops for `KICK_REST_TIME` is downed. |
| Onside | Recovery past `ONSIDE_MIN_TRAVEL` (10 yd) exists as the `world.onside` mutator, **off by default**. Turning it on belongs to #42. |
| Punt | **K** cycles the kick call on any scrimmage down. The punter lines up `PUNT_DEPTH` 10 yd deep and the returner drops `PUNT_RETURNER_DEPTH` 38 yd past the LOS. A touchback comes out to the 20 (`PUNT_TOUCHBACK_FRACTION`). Fake punts play a normal down. |
| Field goal | **K K**. The holder sets up `FG_HOLD_DEPTH` 7 yd deep. Good = between the uprights and above the 3.3 yd crossbar at the end line. A miss gives the defense the ball at the kick spot, or at its 20 if that's further out. |
| Tries | 1 point = PAT kick from the 15. 2 points = a scrimmage play from the 10. |
| Blocks | A rusher within `KICK_BLOCK_REACH` (1 yd) of the ball during its first `KICK_BLOCK_WINDOW` (5 yd), while it is no higher than `KICK_BLOCK_HEIGHT` (3 yd), blocks it. Kickoffs can't be blocked. The ball pops up live (scoop and score). If the kicking team recovers, it plays the down out. |
| Bots | 4th-down rule: try a FG within `AI_FG_MAX` (50 yd); go for it on 4th & ≤2 past midfield; otherwise punt. They always kick the PAT (#69), vary kickoff depth, cover in lanes, and set a return wall. |

Kick flight is a ballistic solve: `world.kick_velocity(kind, from, target, power)`. Speed runs from `KICK_SPEED_MIN` 14 to `KICK_SPEED_MAX` 27 yd/s, and the launch angle depends on the kick (`KICK_ANGLE`: punt 52°, FG 38°, kickoff 42°).

A kickoff or punt return touchdown counts as a special-teams score in the [postgame stats](progression.md).

## Design decisions
- **Kicks reuse the passing aim.** The aim point sets the direction and the distance used to calculate power (pillar 3). Rejected: automatic kicks from distance plus a random roll (no skill, nothing to watch) and a separate swinging-needle minigame (a new input mode and UI per kick type).
- **Kicks are deterministic.** No random wobble, so the skill is aim plus power. The ball flies through the real sim, so blocks, catches, bounces and touchbacks are physics, not dice.
- **Onside is a mutator, off by default.** Gridiron removed onside kicks, and backyard rules (#42) own turning it on.
- **The online path:** `kick`, `kick_call` and `toss` actions are sanitized and routed through the host. Snapshots carry the kick call, the kicked flag and the toss winner. The huddle is skipped on kickoffs.
- **Tests that assumed the old automatic touchback** were changed to expect live kickoffs. `game_flow` resets to a scrimmage for its legacy steps (`opening_kickoff`), and `net_test`'s host runs `--no-kickoff`.

## Code and tests
- `src/sim/world.gd`: `call_kick`, `setup_kickoff`, `kick`, `kick_velocity`, block and rest rules
- `src/sim/match.gd`: toss, `_kickoff`, kick outcomes and spots
- `src/sim/tuning.gd`: `KICK_*`, `PUNT_*`, `FG_*`, `ONSIDE_*`, `AI_FG_MAX`
- `src/sim/ai.gd`: `_kick_protect`, `_bot_kick`, `_kick_coverage`, the 4th-down rule
- `src/game/main.gd`: K / 1 / 2 handling, instant kick input in `_set_charging()`, distance-based `kick_power()` and arc preview
- Tests:
  - `tests/test_kicking.gd`: about 30 tests, including a full bot match with kicks
  - `tests/game_flow.gd`: toss, aimed kickoff + arc + return, K punt, K K field goal
  - The scoring, clock and match-size tests expect live kickoffs

## Open issues
- #67 D06 Kicking stats: FG made/att + long, punt avg, kick/punt return yards
- #68 D07 Kick meter art: stepped power meter beside the kicker + ball on a tee
- #69 D08 Fair catch + bot 2-pt decisions
- #42 C27 Backyard rules / trick plays (onside kick mutator)
