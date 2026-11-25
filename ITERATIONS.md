# Iteration Log

## 000: Scaffold (2026-11-24)
- Godot 4.3 project, headless unit-test runner (`scripts/test.sh`), smoke boot (`scripts/smoke.sh`), parity backlog, loop procedure.
- Tests: harness self-test only.

## 001: A01 Field + player (2026-11-24)
- Sim: `src/sim/field.gd` (regulation geometry, zones, playable clamp), `src/sim/player_motion.gd` (accel/decel, run 7 yd/s, sprint 9.5 yd/s, stamina drain/regen, exhaustion lockout until 25%), `src/sim/tuning.gd`.
- Game: procedural field (turf, end zones, 5-yd lines), capsule player (WASD + Shift), smoothed follow camera, stamina HUD.
- Better than Gridiron: exhaustion lockout makes sprint a decision.
- Tests: 13 unit passing; smoke boot 300 frames clean. `smoke.sh` allowlists one verified Godot 4.3 headless dummy-renderer message.
- Known gaps: keyboard only (no gamepad/InputMap yet; A27), no animation, camera doesn't collide.

## 002: A02 Ball + snap (2026-11-24)
- Sim: `world.gd` (authoritative World: athletes, ball, phase PRESNAP/LIVE/DEAD, formation, neutral-zone clamp, timed snap flight, events), `athlete.gd` (id/team/role), `ball.gd` (HELD/IN_FLIGHT/LOOSE/DEAD).
- Game: 7v7 athletes rendered in team colors; you control the QB; Space snaps, R resets; ball mesh follows sim; HUD shows phase.
- Tests: 19 unit passing (+6); smoke clean.
- Known gaps: non-controlled athletes stand still (bots in A14); no play end yet (A05).

## 003: A03 Precision physics passing (2026-11-24)
- Sim: `passing.gd` ballistic solver (bisection on launch angle to cross aim point at catch height; out of range → 45° falls short), `lead_target()` receiver prediction; World.throw (holder, LIVE, behind LOS, one forward pass), ball flight with gravity, ground = incomplete → DEAD. Throw-on-the-run inherits 30% of QB velocity.
- Game: mouse-aimed ground reticle, hold LMB/J to charge (0.9 s to full), release to throw, trajectory preview arc (better than Gridiron).
- Tests: 27 unit (+8). New `tests/game_flow.gd` scripted e2e through the real scene, wired into smoke.sh (7 checks).
- Known gaps: no catching yet (A04); D01 logged for gamepad/InputMap.

## 004: A04 Catching (2026-11-24)
- Sim: reach-volume catching (radius 1.2 yd, height window 0.3–2.6 yd, closest wins), defenders contest from radius + 0.35 yd margin → "breakup", out-of-bounds catch → incomplete, thrower can't catch own pass, **C/OL ineligible receivers** (found by tests: the C was catching flat passes over his head).
- Game: placeholder go routes for WR/RB after snap; control switches to the receiver on a catch; R resets control to QB.
- Tests: 34 unit (+7, one older passing test retargeted off the C's line); game flow 10 checks incl. real lead pass → catch → control switch.
- Known gaps: auto-catch only (catch/dive button later), defender "win" is a breakup until interceptions (A13).

## 005: A05 Tackling (2026-11-24)
- Sim: committed dive tackle (0.35 s @ 11 yd/s in facing dir, 1.0 yd reach; miss = 1.0 s grounded), `facing` on motion, whistle on tackle/carrier OOB → DEAD + `dead_ball_spot`, sacks behind LOS, `play_time`.
- `src/sim/ai.gd`: placeholder AI moved into the sim (go routes; defenders hold 2.5 s then pursue with lead + dive in range; pursue immediately after a catch). Base for A14 bots.
- Game: E / RMB dive, diving/grounded athletes lie flat, HUD shows whistle reason + spot.
- Tests: 41 unit (+7); game flow 13 checks (catch → AI pursuit → tackle → HUD reason). Flow caught a HUD ordering bug (generic whistle overwrote reason).
- Known gaps: no broken tackles/stiff-arm yet (could come with B06 juice), defense not human-playable until A11 team select.
