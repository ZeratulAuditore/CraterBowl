# 013: Routes + play calling (A12)

## Goal
The offense calls a play before the snap, receivers run defined routes, and human receivers can choose their own route in real time, with routes drawn for teammates so the QB knows where everyone is going.

## How Gridiron does it
"Precision passing, strategic routes, and real-time coordination with teammates."

## Design
- `src/sim/routes.gd` (pure): 9 routes as waypoint offsets from the receiver's alignment (+x = toward the field center, mirrored per side): GO, SLANT, OUT, IN, CURL, POST, CORNER, FLAT, WHEEL. A playbook of 6 plays maps receiver order (left WR, right WR, RB) → routes: Verticals, Slants, Mesh, Curls, Flood, Deep Shot.
- World: `route_of[athlete_id]` (route name, set presnap); at the snap, absolute `route_paths` are computed from each eligible receiver's spot. The offense defaults to Verticals each play.
- AI receivers follow their path (advance at 1 yd), then continue along the final segment's direction. Lane avoidance is kept.
- Actions (authoritative via `Protocol.apply_action`): `play` (any offense player, presnap) and `route` (an eligible receiver sets their own route, presnap). Snapshots carry the play + per-athlete route ids so clients draw the same lines.
- Game: Q cycles plays, F cycles your route; route lines are drawn presnap for your own team only (the defense doesn't see them).

## Options
1. Free-running receivers with no routes. That's the current placeholder, and it isn't parity.
2. **Route library + playbook + per-receiver override** (picked). Supports both AI teammates and human coordination.
3. A full play-art editor. That's a Phase B idea.

## Better than Gridiron
Route lines are visible to your team only, so the QB can read a human receiver's chosen route without voice chat.

## Acceptance criteria
- Mirroring: a SLANT from the left side moves toward +x; from the right side toward −x. OUT moves toward the sideline.
- Calling a play assigns routes to eligible receivers only (WR, WR, RB), never to QB/C/OL.
- An AI receiver on SLANT, after 1.5 s, has advanced past the LOS and moved inside.
- Actions: `play` rejected for the defense and during LIVE; `route` only for the sender if they're an eligible receiver.
- The snapshot round trip carries the play and routes.
- Flow: call Slants → route lines visible → snap → WR breaks inside.
