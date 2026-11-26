# Controls (Gridiron-style layout)

| Key | Before the snap | During the play |
|---|---|---|
| WASD | Move | Move (relative to the camera; for the passer, relative to the aim) |
| Shift | Sprint | Sprint |
| Space | Snap (offense) / break stance (defense) | |
| **Q** | Open / close the play picker | **Spin left** |
| **E** | | **Spin right** |
| **F** | Cycle your route | **Dive**: tackle attempt on D; with the ball, dive for yards, down where you land (score if you cross the goal line) |
| C | | Dash |
| Hold RMB | | Block (shield) |
| LMB / J | | Throw. Passer: **hold to charge distance, release to throw** |
| **Mouse wheel** | Scroll the taunt picker | Scroll the taunt picker |
| **G** | Taunt (selected in the picker) | Taunt |
| Hold Tab | Scoreboard | Scoreboard |
| R / V | Next play / instant replay | |

Spins and dashes spend **move charges** (2 max, refilled as you run, about 20 yards per charge; the meter
sits by your athlete card). A spin is angled 35° left (Q) or right (E) of the way you're facing. A dive
tackle that lands mid-spin misses, and a spin sheds a block.

Taunts are cosmetic. There are 8, rate-limited to one per second, and everyone in the match sees the animation and speech bubble.

## QB POV aiming
While you're the passer (QB before the forward pass, including lining up pre-snap; any ball holder in
Chaosball) the mouse is captured and steers an over-the-shoulder camera:

- **Direction** is where you look.
- **Height** comes from looking up or down. Launch angle = view pitch + 10°, clamped −10°…70°. The crosshair shows `LOFT`.
- **Distance** comes from holding the throw: charge sets the ball's speed. The bar under the crosshair fills to full power in 0.9 s.
- **Aim-zoom:** while you hold, the camera zooms in with the charge (FOV 65° → 45° at full power) and eases back on release.
- The landing reticle and arc preview show where it will come down.

Everyone else uses the orbit camera: mouse X orbits, mouse Y sets how far ahead it looks
(middle-drag before the snap). The ESC menu releases the mouse. On a gamepad, the right stick aims.

## Gamepad
Left stick move · right stick QB aim · A snap · B dive · X / Y spin left / right · D-pad down dash ·
RT pass · LT sprint · LB scoreboard · RB lob. Taunts are not on the pad yet.

## Where it lives
- Sim: `src/sim/athlete.gd` (move charges, spin/dash, block), `src/sim/world.gd` (`spin(side)`, `evade`,
  `throw_dir`, `emote`, carrier-dive whistle), `src/sim/passing.gd` (`velocity_for`), `src/sim/emotes.gd`.
- Wire: `src/net/protocol.gd` (`spin {s}` / `spin|dash {dir}` / `emote` / POV `throw {d, ang, p}`; flags BLOCK 8, SPIN 16, SPIN_LEFT 32).
- View: `src/game/main.gd` (POV + orbit camera, mouse capture, keys), `src/game/emote_picker.gd`, `src/game/player.gd`.
- Tests: `tests/test_moves.gd`, `tests/test_live_controls.gd`; real-input steps in `tests/game_flow.gd`.
