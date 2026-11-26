# Controls (Gridiron-style layout)

| Key | Action |
|---|---|
| WASD | Move (relative to your view while you're the passer) |
| Shift | Sprint |
| Space | Snap |
| **Q / E** | **Spin left / right** (during the play): 0.4 s spin + sidestep; any dive tackle that lands mid-spin misses. 1.2 s cooldown. |
| **F** / RMB | **Dive** (during the play): tackle attempt on defense. With the ball, dive for extra yards and you're down where you land (or score if you dive across the goal line). |
| **Mouse wheel** | Scroll the taunt picker (right side of the screen) |
| **G** / middle click | Perform the selected taunt (cosmetic, 1 s rate limit, everyone sees it) |
| LMB / J (hold) | Charge a throw, release to throw |
| Q / F before the snap | Next play call (defensive call on D) / cycle your route. Same keys, different job before the snap |
| X / Y / L | Flip play / auto call / last call (huddle) |
| Tab / T | Switch position / team |
| R / V | Next play / instant replay |

## QB POV aiming
While you're the passer (QB before the forward pass, or any ball holder in Chaosball)
the mouse is captured and steers your camera, which swings to an over-the-shoulder view:

- **Direction** is where you look (yaw).
- **Height** comes from looking up or down. Launch angle = view pitch + 10°, clamped to −10°…70°.
  The crosshair shows the current `LOFT` angle.
- **Distance** comes from how long you hold the throw: charge sets the ball's speed.
- The landing reticle and arc preview show where the throw will come down with the current charge.

Once the ball is out (or you scramble past the line), the camera returns to the normal follow cam
and the mouse is released. The ESC menu also releases it. On a gamepad, the right stick looks.

Ctrl (lob) only applies to the old click-to-aim path, which tests/bots still use (`main.pov_enabled = false`).

## Gamepad
Stick move, A snap, B dive, LB/RB spin, X next call (pre-snap), Y flip, RT throw, LT sprint, right stick POV look,
L3 lob, R3 switch position. Taunts are not on the pad yet.

## Where it lives
- Sim: `src/sim/athlete.gd` (spin state), `src/sim/world.gd` (`spin`, `throw_dir`, `emote`, carrier dive whistle),
  `src/sim/passing.gd` (`velocity_for`), `src/sim/emotes.gd` (taunt list).
- Wire: `src/net/protocol.gd` (`spin` / `emote` / POV `throw` actions, spin snapshot flags).
- View: `src/game/main.gd` (POV camera, mouse capture, keys), `src/game/emote_picker.gd`, `src/game/player.gd` (spin + taunt animation, speech bubble).
- Tests: `tests/test_moves.gd`; real-input steps in `tests/game_flow.gd` (frames 7700+).
