# Movement

Feature-level doc: how this works for players **today** on `main`. Design/implementation detail: [architecture](../design/architecture.md). Open work: GitHub issues labelled `area:movement` (listed below).

## Summary
You run at a fixed speed with instant starts and stops, sprint on a stamina bar, and have two special moves (dash and
spin) that spend charges earned by running. Defenders tackle with a committed dive that costs a second on the ground
if it misses. All movement is camera-relative.

## How it plays

### Controls
Defaults from `src/ui/controls.gd`; every keyboard action can be rebound in Settings.

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | W A S D (camera-relative) | left stick |
| Sprint | Shift | LT or L3 |
| Dash | C | D-pad down |
| Spin | F | Y |
| Dive tackle | E | B |
| Block (shield) | hold right mouse | none |
| Snap / break stance (defense: double-tap) | Space | A |
| Look / aim | mouse (middle drag pre-snap) | none (#33) |

Passing, handoff and play-call keys are in [offense.md](offense.md).

### Run and sprint
- Nobody on offense moves before the snap; set defenders need a Space double-tap to roam. Pre-snap rules are in
  [defense.md](defense.md#pre-snap-stance-and-roam).
- `RUN_SPEED` 7.0 yd/s, `SPRINT_SPEED` 9.5 yd/s. Velocity is set directly from input each step: no acceleration
  ramp and no slide on stop. Diagonals are clamped to unit length.
- W is "up the screen". On defense the camera faces the offense, so W moves you toward the line of scrimmage.
- Sprint needs movement input. Stamina drains `STAMINA_DRAIN` (0.25/s, so 4 s from full) and regenerates
  `STAMINA_REGEN` (0.15/s) whenever you aren't sprinting. Hitting 0 locks sprint until stamina is back to
  `STAMINA_LOCKOUT_RECOVER` (25%). The HUD bar turns red below 25% or while locked.
- Stamina also feeds fumble risk on hits; see [rules.md](rules.md#turnovers).
- Players are clamped `OOB_MARGIN` (2 yd) beyond the sidelines and end lines. A carrier who steps out is whistled dead.

### Dash and spin
- Only during live play, only with at least one charge, not while diving, grounded or already in a move.
- The move goes in your input direction (or your facing if no input) and locks steering for its duration.

| Move | Speed | Time | Distance | Extra effect |
|---|---|---|---|---|
| Dash (C) | `DASH_SPEED` 13.0 | `DASH_TIME` 0.22 s | about 2.9 yd | breaks your current block |
| Spin (F) | `SPIN_SPEED` 7.5 | `SPIN_TIME` 0.32 s | about 2.4 yd | breaks your block; can't be tackled or blocked while spinning |

- Charges: up to 2 (two circles next to the stamina bar). Each move costs 1. You earn `MOVE_CHARGE_PER_YARD`
  (0.05) per yard moved during live play, so one charge per 20 yd. Standing still, being in a move, and pre-snap
  movement earn nothing. Charges carry over between plays.
- You can't throw or dive during a move. A move cancels the shield.

### Dive tackle
- **E** launches a dive in your facing direction at `DIVE_SPEED` (11 yd/s) for `DIVE_TIME` (0.35 s), about 3.9 yd.
- Any opponent of the carrier whose dive brings him within `TACKLE_REACH` (1.0 yd) tackles him, unless the carrier is
  spinning. A tackle can also strip the ball (rules link above).
- After the dive you are grounded for `DIVE_RECOVER` (1.0 s), sliding to a stop. Grounded players don't collide or block.
- Anyone can dive, including the carrier (a lunge; the play stays live while he lies there).
- Bots dive when within `AI_DIVE_RANGE` (2.0 yd) of the carrier.

## Design decisions
- The sim works in yards on a 2D plane: x across the field (0 to 53.33), y down it, goal lines at 0 and 100,
  10 yd end zones. One render unit is one yard (sim y maps to render -z).
- Committed dive over contact tackles (no skill) or a tackle meter (breaks flow). Whiffing costs a second.
- Exhaustion lockout makes sprint a decision, not a held button.
- Instant velocity replaced the original accel/decel model in the live-controls rework; `DECEL` now only
  shapes the post-dive slide.
- Charges come from distance run, not time, so players can't bank moves standing in the huddle.
- Spin gives tackle and block immunity; dash is faster but gives neither. That is the trade-off between the two.

## Code and tests
- `src/sim/player_motion.gd` — run/sprint speed, stamina, lockout, clamping.
- `src/sim/athlete.gd` — dive, recovery, dash/spin state (`start_move`, `start_dive`, `move_charge`).
- `src/sim/world.gd` — `step_athlete` (charge gain), `evade`, `tackle`, `_check_tackles`.
- `src/ui/controls.gd` — action table, rebinding, gamepad map. `src/ui/launch.gd` — gamepad to key translation.
- `src/game/main.gd` — `read_input` (camera-relative), key handling. `src/game/overlay.gd` — stamina bar, charge circles.
- Tests: `tests/test_player_motion.gd`, `tests/test_live_controls.gd`, `tests/test_tackling.gd`,
  `tests/test_turnovers.gd`, `tests/game_flow.gd` (C and F consume charges), `tests/menu_flow.gd` (rebinding, gamepad).

## Open issues
- #5 C03 Movement moveset: jump, dive, dash, spin, stiff-arm
