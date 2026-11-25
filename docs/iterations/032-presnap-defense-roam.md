# 032: Pre-snap defensive roam + line-of-scrimmage barrier (C08d, split from C08b)

## Goal
Defenders start each play set in their stance. A non-lineman presses **Space** to break the stance and
roam their side of the ball before the snap. A see-through, animated barrier at the line of scrimmage
shows where they have to stop.

## How the genre does it (reference screenshot, 2026-11-25)
- Defenders spawn in stance. Pressing Space stands your player up and lets you walk around before the
  snap. DL stay down.
- You can't cross the line. A translucent hex-pattern wall stands at the LOS and animates (shimmer and
  scroll), so the limit is visible.
- Only the genre mechanic is borrowed. The art is ours: it reuses our moon-dome hex look, not theirs.

## What we have today (verified in code)
- `World.step()` moves **every** athlete during PRESNAP, on both sides and in every role, DL included.
  `_enforce_neutral_zone()` hard-clamps offense to `los_y - 0.5` and defense to `los_y + 0.5`. So
  humans can already move pre-snap. Nothing locks them, and nothing shows the line, so you just hit an
  invisible stop.
- Space on defense does nothing. `Protocol.apply_action("snap")` rejects a defender, and the HUD says
  "Space: let them snap", which is misleading.
- Bots don't move pre-snap: `ai.think()` returns `{}` unless the phase is LIVE.
- Net clients predict their own athlete with `me.step()` but never apply the neutral-zone clamp. On a
  client, pushing into the line runs past it and then rubber-bands back on reconcile.
- `player.gd` already plays `Crouch_Idle` for linemen and `u2/Idle_Shield` for LB/CB/S pre-snap.

## Design options

### Unlock model
1. **Always free (status quo, plus the barrier only).** Least work. But DL can wander, there's no
   "set" look, and Space stays dead on defense.
2. **Stance-lock + Space to break (pick).** Matches the reference. Space gets a meaning on defense,
   formations look set until someone commits, and the DL exception is free.
3. Stance-lock + auto-unlock once you push a direction for a short time. No key to learn, but you'd
   break stance by accident when nudging the camera or stick, and there's no deliberate "I'm moving"
   beat.

**Pick: 2.** Rule: Space on defense *breaks stance* (one-way for the rest of the play). A locked
athlete ignores movement input but can still turn to face (so you can look around). DL can never
unlock. Offense is unchanged here; offensive motion is C09.

### Barrier
1. Recolor the existing `line_marker` ground strip. Cheap, but it's flat and doesn't read as "you
   can't pass".
2. **Vertical translucent hex wall at the LOS (pick).** A single quad spanning the field width,
   about 2.2 m tall, with a hex-grid shader: base alpha near 0.08, glowing hex edges, slow upward
   scroll, and a gentle pulse.
3. A full neutral-zone box (two walls, 1 yd apart). It's more accurate, but it doubles the visual
   noise and the camera sits behind one wall anyway.

**Pick: 2,** plus two touches that improve on the reference:
- **Proximity reveal:** the wall's alpha rises near any athlete within about 2 yd, local player
  weighted highest. It's nearly invisible from the backfield and solid right where you're about to
  touch it.
- **Contact ripple:** when the clamp actually stops someone, a hex ripple spreads from the contact
  point. You get feedback instead of an invisible stop.
- **Drop at snap:** at the snap, hexes dissolve on a noise threshold over about 0.25 s, which sells the
  "go" moment.

## Implementation plan

### Sim (`src/sim/`, pure and deterministic)
1. `athlete.gd`: add `var set_lock := false`. `reset_state()` does **not** touch it; `setup_formation`
   owns it.
2. `world.gd`:
   - `setup_formation()`: `a.set_lock = (a.team != offense_team)` for every athlete. The defense lines up
     set; offense keeps current behavior.
   - `func break_stance(id) -> bool`: returns false unless phase is PRESNAP, `a.team != offense_team`,
     `a.role != Role.DL`, and the athlete is currently locked. Otherwise it clears `set_lock` and emits
     `event("break_stance", {id})`.
   - `step()`: during PRESNAP, a locked athlete steps with `dir = Vector2.ZERO` but takes facing from
     the input. Add a small `Athlete.face(dir)` helper so facing updates without moving.
   - `_enforce_neutral_zone()`: return true when it actually clamped. Collect contacts in a per-step
     `barrier_hits: Array` (x positions) for presentation to read. Presentation never owns the rule.
   - `snap()`: clear all `set_lock` (harmless, and keeps LIVE paths unaware of the lock).
3. `tuning.gd`: `BARRIER_HEIGHT`, `BARRIER_REVEAL_DIST`, `BARRIER_DROP_TIME`.

### Input and routing
4. `protocol.gd` `apply_action("snap")`: offense calls `w.snap()` as before. On defense it calls
   `w.break_stance(athlete_id)`. One key, routed by side. No new keybind, and the `controls.gd` label
   becomes "Snap / break stance".
5. `main.gd` HUD on defense pre-snap: "PRE-SNAP: Space to break stance" while you're locked and not DL,
   then "ROAMING" once unlocked. DL see "PRE-SNAP: hold your stance". This replaces the misleading
   "let them snap".
6. `game_flow.gd`: press the real KEY_SPACE through `_key()` while on defense and assert the athlete
   unlocks and then moves (rule from LOOP.md: test the real handler).

### Net
7. Snapshot: add per-athlete `set_lock` (a bitmask int is fine) in `encode_snapshot`/`apply_snapshot`.
8. Client prediction: after `me.step()` in `_physics_process`, apply the same lock and clamp. Expose
   `world.presnap_constrain(a, dir) -> dir` and `world._enforce_neutral_zone(a)` (made public), so the
   predictor and the server share one rule. Also apply them inside `client_predictor.reconcile()`
   replays, or reconcile will un-clamp. This fixes the existing rubber-band too.
9. `net_client.gd`: the client sends a defensive "snap" and the host reports the athlete unlocked.
   Client input toward the LOS never ends up past `los_y + 0.5` after reconcile.

### Presentation (`src/game/`)
10. `art/los_barrier.gdshader` (spatial, unshaded, alpha blend, cull disabled, GL-compat safe, so **no
    instance uniforms**):
    - Hex grid from UV × field width.
    - `uniform float drop` (0 to 1) drives the dissolve.
    - `uniform vec4 reveal[8]` holds (x, strength) for the nearest athletes and `uniform vec4 ripple[4]`
      holds (x, age), as plain uniform arrays.
11. `presentation.gd`: build the barrier mesh once and move it to `z = -los_y` each play. It's visible
    in PRESNAP, plays the `drop` tween on the `snap` event, and is hidden in LIVE/DEAD. Each frame it
    feeds reveal points from athletes within `BARRIER_REVEAL_DIST`, and pushes new ripples from
    `world.barrier_hits`.
12. `player.gd`: a locked LB/CB/S keeps `u2/Idle_Shield`. Once unlocked and idle, play `Idle`, so a
    standing roamer reads differently from set teammates, like the reference shot.
13. Replay: the barrier keys off the recorded `phase` and positions only. No new replay fields.

### Out of scope (follow-ups to log under Discovered)
- Bot defenders shading or creeping pre-snap. That belongs to C08b zone landmarks.
- Offensive pre-snap discipline: false start, and illegal motion vs one-man motion (C09).
- Re-setting (going back into stance) after breaking it.

## Acceptance criteria
- After `setup_formation`, every defender is locked and every offensive athlete is unlocked.
- A locked defender given movement input for 1 s pre-snap ends within 0.01 yd of its start, and its
  facing follows the input.
- `break_stance` succeeds for LB/CB/S pre-snap. It fails for DL, for offense, in LIVE/DEAD, and when
  the athlete is already unlocked.
- An unlocked defender driven at the LOS for 2 s never has `y < los_y + 0.5`, and that step records a
  `barrier_hits` entry.
- `snap()` clears every lock. The next `setup_formation` re-locks the defense.
- `Protocol.apply_action({"a":"snap"})` from a defender unlocks them and doesn't snap the ball. From
  the offense it still snaps.
- Snapshot round-trip preserves `set_lock`.
- Over net, the client's predicted position never crosses the clamp, including after reconcile.
- game_flow: real Space on defense pre-snap → unlocked → moves. The HUD shows the break-stance prompt
  before and ROAMING after.
- shot.sh: pre-snap frames show the barrier, faint far away and brighter near the line players. A
  frame just after the snap shows it dissolving, and a LIVE frame shows it gone. **View the PNGs.**
- `./scripts/test.sh` and `./scripts/smoke.sh` are green. No older test is weakened.

## Tests
- New `tests/test_presnap_roam.gd`: lock, unlock, DL rule, clamp plus hits, snap clears, re-lock, and
  protocol routing.
- Extend `tests/test_net*` / `net_client.gd` (unlock over the wire, clamp under prediction),
  `tests/game_flow.gd` (real key), and shot.sh runs:
  `./scripts/shot.sh --frames=20,60 --do=10:team --press=30:SPACE` to roam toward the line, then
  frames around the snap.

## Risks
- **Space conflicts.** Space also pauses the replay viewer, but that's handled earlier in
  `_unhandled_key_input`, so it's fine. Check that the Space key on the TRY screen (1/2) isn't affected.
- **Uniform arrays on llvmpipe/GL-compat.** If they misbehave, fall back to packing reveal and ripple
  data into a small 8×1 `ImageTexture`.
- **Transparency sorting.** The wall is see-through and stands between the camera and the far players.
  Keep it unshaded with `depth_draw_never` so it can't hide athletes behind it.
