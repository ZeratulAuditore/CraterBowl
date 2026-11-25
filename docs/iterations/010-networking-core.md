# 010: Networking core (A10a)

A10 was split: **A10a** (this) is the authoritative host/join + protocol; **A10b** is prediction/interpolation.

## Goal
Friends can host and join a match over the internet/LAN. The host runs the authoritative sim; clients send inputs and render server snapshots.

## How Gridiron does it
Online 7v7 with matchmaking and private matches; each person controls one athlete.

## Design
- `src/net/protocol.gd` (pure): `encode_snapshot(match)` / `apply_snapshot(match, snap)` (compact arrays), `sanitize_input(msg)`, and `apply_action(match, athlete_id, action)`. That last one is the **single server-side entry point for human actions** (snap/throw/tackle/try), reusing World/Match validation so clients can't cheat beyond what the rules allow.
- `src/net/net_session.gd` (Node): ENetMultiplayerPeer + SceneMultiplayer `send_bytes` with packets serialized by `var_to_bytes` / `bytes_to_var` (no objects decoded). Channels: inputs + snapshots unreliable-ordered @ 30 Hz; actions, welcome and events reliable.
- **Athlete assignment:** the host plays team 0's QB/LB. The first joiner gets team 1's QB/LB (instant 1v1), then remaining athletes alternate teams. Unassigned athletes stay AI.
- **Fixed athlete per person online** (Gridiron parity); the single-player control-switch on catch stays offline-only.
- The main scene reads `-- --host [--port=N]` / `-- --join=ADDR [--port=N]`. Offline is the default.

## Options
1. Godot high-level RPC + MultiplayerSynchronizer. It ties sim state to scene nodes and fights the pure-sim design.
2. **Raw `send_bytes` + our own snapshot codec** (picked). Explicit bandwidth, testable codec, and a natural place for prediction later.
3. Lockstep. Too fragile over the internet with 14 athletes.

## Better than Gridiron
The host keeps AI for empty slots, so 1v1 friend games work without filling lobbies.

## Acceptance criteria
- Snapshot round trip: athletes (pos/vel/facing/role/dive/grounded), ball, phase, offense, downs, score, clock, match state all match after apply.
- `sanitize_input` clamps dir length ≤ 1, rejects non-finite values, and clamps throw power to 0..1; unknown actions are dropped.
- `apply_action` routes to the rules: a tackle only dives the sender's athlete; a throw only works if the sender holds the ball.
- Two-process test: the server hosts, the client joins → welcomed with an athlete id, receives snapshots, its snap action makes the play LIVE, its movement input moves its athlete in snapshots.
