# 004: Catching (A04)

## Goal
Receivers catch passes that come within reach. Contested balls resolve fairly, and catches out of bounds are incomplete.

## How Gridiron does it
Receivers run routes and catch precision-thrown balls; defenders lock them down and break up passes.

## Options
1. Physics collision with the ball. Jittery and non-deterministic.
2. **Reach volume:** each step, athletes within CATCH_RADIUS (horizontal) of the ball, with ball height inside the catch window [0.3, 2.6] yd, are candidates. The closest candidate wins. **Picked.** Deterministic, cheap, server-friendly.
3. A catch button with a timing window. Planned as a "high-point/dive" upgrade; auto-catch first so the core loop works.

## Rules
- The thrower can't catch their own pass (Chaosball overrides this later).
- **Contested:** if the best offensive and best defensive candidates are within CONTEST_MARGIN (0.35 yd) of each other's distance, the pass is broken up → incomplete. A clear defender win is also a breakup for now (interceptions are A13).
- A catch while the receiver is out of bounds → incomplete.
- A catch → ball HELD by the receiver, play continues LIVE, "catch" event.

## Better than Gridiron
Contest margin makes "body position" matter. The defender doesn't need to be closer, just close enough.

## Game
Placeholder: WRs/RB run a straight "go" after the snap (real routes A12, bots A14). After a catch, local control switches to the receiver.

## Acceptance criteria
- A pass led to a running WR is caught; ball held by WR, phase LIVE, "catch" event.
- A pass far from anyone lands incomplete.
- The thrower can't catch their own pass.
- A ball above the catch window sails over a receiver.
- A contested ball (defender ~equally close) → incomplete with "breakup" event.
- A receiver standing out of bounds → incomplete.
- Game flow: lead pass to WR → caught → control switches to WR.
