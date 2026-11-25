# 011: Netcode feel (A10b)

## Goal
Online play feels local: your own athlete responds instantly, and everyone else moves smoothly instead of in 30 Hz steps.

## How Gridiron does it
Online 7v7 third-person play, where responsive movement is essential. (Laggy, rubber-banding play is a common complaint about games in this niche, and one of our PLAN.md pillars.)

## Design
- **Client-side prediction + reconciliation** (`src/net/client_predictor.gd`, pure). Every input carries a `seq`. The client steps its own athlete immediately and keeps unacked inputs. Snapshots carry `ack[athlete] = last seq processed`. On a snapshot: set own athlete to server state, drop acked inputs, replay the rest.
- **Snapshot interpolation** (`src/net/interpolator.gd`, pure). Snapshots are buffered by server tick, and other athletes and the ball render ~100 ms in the past, lerped between bracketing snapshots. It holds the last state on underrun (no extrapolation spikes).
- **Server:** records the last input seq per athlete and includes acks in every snapshot.

## Options
1. Pure interpolation for everyone, including yourself. Smooth but laggy controls; that's the classic "bad netcode" feel.
2. **Predict self, interpolate others** (picked). The industry standard for action games.
3. Full rollback of the whole sim. Overkill: 14 bodies, server-authoritative contacts.

## Better than Gridiron
Reconciliation replays your inputs, so corrections are rare and small. Mispredictions only happen on contact (blocks/collisions), which the server owns.

## Acceptance criteria
- Predictor: with simulated latency, the predicted position leads the server's, and after acks catch up it matches the server within 0.01 yd.
- Predictor drops acked inputs (buffer doesn't grow unbounded).
- Interpolator: sample midway between two snapshots returns the midpoint; before the first/after the last returns the endpoints; out-of-order snapshots are ignored.
- Protocol: input seq is sanitized (int ≥ 0); snapshot carries acks.
- Net test: own athlete moves locally within 2 ticks of input (before any round trip).
