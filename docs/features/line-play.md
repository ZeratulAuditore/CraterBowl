# Line play

Feature-level doc: how this works for players **today** on `main`. Design/implementation detail: [architecture](../design/architecture.md). Open work: GitHub issues labelled `area:line-play` (listed below).

## Summary
Blocking is a sim of body circles plus engagement pairs. A blocker who meets a defender face-on holds him for up to
1.5 s, dragging most of his movement along. Bot linemen pass-protect or run-block automatically. Humans block by
holding right mouse (a "shield"). Rushers beat blocks by waiting out the hold or with a spin or dash.

## How it plays

### Bodies
- Every standing athlete is a circle of `BODY_RADIUS` (0.45 yd); overlaps push both apart equally. Grounded
  (diving or recovering) athletes don't collide.

### Engagement rules
- Only the team in possession blocks, only during live play, and never the ball carrier.
- A block forms when the blocker faces the defender (`ENGAGE_FACING_DOT` 0.3) within `ENGAGE_DIST` (1.0 yd), and the
  defender isn't grounded, spinning, already engaged or immune.
- While engaged the defender's movement each step is 70% the blocker's and 30% his own (`BLOCK_DRIVE`).
- The block ends after `BLOCK_HOLD` (1.5 s), when the blocker can't act or gets the ball, or when either player
  dashes or spins. The defender is then immune for `BLOCK_IMMUNITY` (0.75 s) and the blocker can't re-engage for
  `BLOCKER_BEATEN` (1.5 s).
- Who may block: C and OL any time; skill players only downfield (after a catch or once the carrier is past the LOS);
  after a takeaway anyone on the returning team. A human holding the shield can block from any position.

### Human blocking (shield)
- Hold **right mouse** while your team has the ball and you aren't the carrier. You move at `BLOCK_SPEED`
  (2.8 yd/s), can't sprint, and keep your facing (so you can backpedal while squared up).
- Without the shield a human never starts a block. "Human" means the athlete's input carries the explicit
  `World.HUMAN` flag that `main.gd` sets for the local player and every joined peer (#62); bots auto-engage. Releasing it drops the block, and so does drifting more than
  about 1.12 yd (`ENGAGE_DIST` + 0.12) from the defender.
- No gamepad binding for the shield yet.

### Pass protection (bots)
- Each bot C/OL targets the nearest standing defender within `PROTECTION_RANGE` (8 yd), moves to a spot 0.9 yd in
  front of him toward the ball carrier, and faces him. Pre-snap art draws a grey line from each blocker to that target.

### Run blocking (bots)
- On a run call each C/OL is assigned, at the snap, the defender closest to a landmark shaded `RUN_BLOCK_LANE_WEIGHT`
  (55%) from the blocker toward the called lane, within 8 yd, one defender per blocker. Pre-snap art shows these pairs.

### Pass rush
- DL bots (and the LB on blitz calls) sprint at the ball carrier, leading him by up to 0.6 s, and dive within
  `AI_DIVE_RANGE` (2.0 yd).
- A human rusher can wait out the 1.5 s hold, or spend a move charge: **Q/E** spin or **R** dash both break the block,
  and a spinning player can't be engaged. See [movement.md](movement.md).
- A bot QB drifts away from any rusher within 4 yd (never past the LOS) and throws early under `AI_QB_PRESSURE` (3 yd).

## Design decisions
- Sim circles plus engagement pairs over Godot physics (non-deterministic) or a rock-paper-scissors minigame
  (that is #15).
- A timed shed plus immunity makes a block buy a fixed, readable amount of time.
- The beaten-blocker cooldown is longer than the defender's immunity because a lone C could re-block one LB forever.
- Receivers don't auto-block during a pass play, so they run routes instead of locking onto the nearest defender.
- Human shield and spin/dash shedding came with the live-controls rework (commit `ec09b1e`); before that blocking was
  automatic for everyone.

## Code and tests
- `src/sim/world.gd` — `_can_block`, `_can_be_blocked`, `_step_blocks`, `_release_block`, `_resolve_collisions`,
  `protection_target`, `run_block_assignments`, `evade`.
- `src/sim/player_motion.gd` — shield speed and frozen facing. `src/sim/athlete.gd` — `blocking`, engagement fields.
- `src/sim/ai.gd` — `_protect`, `_approach_block`, `_pursue`, `_qb_pocket`.
- `src/game/main.gd` — right-mouse shield input, `World.HUMAN` flag on local and peer inputs, protection/run-block art.
- Tests: `tests/test_blocking.gd`, `tests/test_live_controls.gd` (shield, spin shed), `tests/test_run_game.gd`
  (run-block targets), `tests/test_training.gd` (blocking station), `tests/visual/peer_human_block_test.gd`
  (host flags a joined peer's lineman as human).

## Open issues
- #15 B01 Line play minigame (leverage / hand-fighting timing, shield resource)
