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

## 006: A06 Blocking (2026-11-24)
- Sim: body circles (0.45 yd) with separation (grounded ignored); auto-engage blocks (blocker facing defender within 1.0 yd) → defender displacement 70% driven by blocker; 1.5 s hold then shed; defender 0.75 s immunity, beaten blocker 1.5 s cooldown. C/OL block anytime; skill players only block downfield (after catch / carrier past LOS).
- Formation now role-based depth + per-athlete `home_x` (bug found: second play kept drifted x from the previous play).
- AI: DL rush at snap; OL/C pass-protect (get between rusher and carrier); route runners sidestep defenders in their lane.
- Measured: full 7v7 pocket holds ~4.0 s before a sack.
- Tests: 51 unit (+10); test.sh now fails on leaked resources; game flow 13 checks pass with live pass rush.
- Known gaps: no player-driven shove/shed input (B01 line minigame), no run-blocking schemes until play calling (A12).

## 007: A07 Downs (2026-11-24)
- Sim: `downs.gd` (offense-frame rules: first down / next down / turnover on downs with mirrored spot, & goal, labels like "2nd & 7 at OWN 28"), `match.gd` (World + Downs; records play results from events, `next_play()` lines up at new LOS and swaps possession). **Two-way athletes** (offense/defense role + x, `World.set_offense`). AI QB throws to most-open receiver after 2.0 s or under pressure.
- Game: human always plays the same athlete (QB on offense ↔ LB on defense); auto next play 2 s after whistle (R to skip); HUD down & distance + side; blue LOS + yellow first-down turf markers.
- Tests: 60 unit (+9); game flow 21 checks. Found + fixed a flow-harness hang (setup error → empty steps → infinite error loop); flow now exits on setup failure and smoke.sh wraps Godot in `timeout`.
- Known gaps: TD/safety (A08) — spots clamp to 1..99 for now; field visuals don't mirror team colors on possession change.

## 008: A08 Scoring (2026-11-24)
- Sim: World detects touchdowns (carrier in opponent end zone, in bounds: runs + end-zone catches). Match tracks score; safety (downed/OOB at y<0, +2 defense); play-based try (1 pt from the 3 or 2 pts from the 10, `choose_try`); simplified kickoff (current defense receives at own 25). Downs clamp no longer needed for TD/safety paths.
- Game: HUD scoreboard (HOME/AWAY), TRY prompt, 1/2 keys choose try, TOUCHDOWN whistle text.
- Tests: 66 unit (+6); game flow 27 checks (forced TD → +6 → 2-pt try good → kickoff to away at 25).
- Known gaps: real kickoffs/returns logged as B09.

## 009: A09 Match flow (2026-11-24)
- Sim: `clock.gd` (2 × 5:00 halves, game clock runs only during LIVE, 20 s play clock during PRESNAP). Match: `tick()` advances clocks + auto-snaps on play-clock expiry; untimed down (play in progress at 0:00 finishes, try still played); halftime → 2nd half kickoff to the team that didn't open with the ball; FINAL with winner, `next_play()` no-op after.
- Game: HUD "H1 4:32 | PLAY 17", FINAL banner with winner; auto-advance stops at final.
- Tests: 72 unit (+6); game flow 32 checks. Flow now runs with `--fixed-fps 60` (uncapped, deterministic): ~53 s → 0.65 s.
- Known gaps: overtime logged as B10.
