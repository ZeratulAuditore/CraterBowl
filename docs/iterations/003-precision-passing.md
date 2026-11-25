# 003: Precision physics passing (A03)

## Goal
The QB aims at a spot, charges power, and throws. The ball flies ballistically (gravity) and passes through the aim point at catch height when thrown from a standstill.

## How Gridiron does it
"Precision physics based passing": aim + timing, receivers on routes, real-time coordination.

## Options
1. Homing/auto-target pass to a receiver. Easy, but there's no skill and it isn't Gridiron.
2. **Aim point + charged power, solved ballistic arc.** Power sets launch speed; the solver finds the flattest angle that reaches the target at catch height. If the target is out of range for that power, the throw goes at 45° and falls short. **Picked.**
3. Fully free angle + power (golf-style). Too fiddly with one stick.

## Physics
- g = 10.73 yd/s² (9.81 m/s²). Release height 2.0 yd, target crossing height 1.1 yd.
- Speed = lerp(12, 30, power) yd/s. Bisection on angle ∈ [−10°, 45°].
- **Throw on the run:** the ball inherits 30% of the QB's velocity, so you have to lead for your own motion too. That's real skill expression.
- Helper `lead_target()` predicts where a moving receiver will be (used by the HUD hint now, bots later).

## Rules
- Only the ball holder, during LIVE play, from behind the LOS, and only one forward pass per play.
- A ball that touches the ground → incomplete → DEAD (catching comes in A04).

## Better than Gridiron
A trajectory preview arc while charging (game side) makes "precision" learnable.

## Acceptance criteria
- A stationary throw with enough power passes within 0.5 yd of the target at catch height.
- A weak throw at a far target falls short.
- More power → flatter/faster: flight time to the same target decreases.
- A throw while running lands offset in the direction of motion.
- Throws are rejected when: not holding, presnap, past the LOS, or a second forward pass.
- The ball hitting the ground → phase DEAD and an "incomplete" event.
- `lead_target` for a receiver running at constant velocity hits them within 1 yd.
