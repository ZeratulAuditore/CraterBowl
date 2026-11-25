# 002: Ball + snap (A02)

## Goal
A ball entity with possession state. The center snaps it to the QB, which starts the play.

## How Gridiron does it
Each play starts with a snap from the line. The QB receives it and the play goes live. One athlete per human.

## Options
1. Ball as a child node of the holder's mesh. Simple, but possession becomes scene state, which is untestable and breaks with networking.
2. **`World` sim owns athletes + ball + phase** (PRESNAP → LIVE → DEAD). The ball has state HELD / IN_FLIGHT / LOOSE / DEAD and a `holder_id`, and its position derives from the holder. **Picked.** It's the backbone for passing, tackling, downs and the network server.
3. An ECS. Too heavy for this team.

## Better than Gridiron
The snap is a short visible flight (0.35 s) rather than a teleport, so timing the snap is readable. Pre-snap neutral-zone clamping means no accidental offsides grief while lining up.

## Acceptance criteria
- `World.setup_formation(los)` places C on the LOS and QB 5 yd behind; offense attacks +y.
- Pre-snap: ball HELD by C, phase PRESNAP; offense can't cross LOS−0.5, defense can't cross LOS+0.5.
- `snap()` only works in PRESNAP; the ball goes IN_FLIGHT, then HELD by QB after SNAP_TIME; phase becomes LIVE at the snap.
- A second snap during LIVE is rejected.
- The held ball follows its holder's position each step.
- Game: Space snaps; you control the QB; several athletes render.
