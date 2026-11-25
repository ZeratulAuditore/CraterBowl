# 005: Tackling (A05)

## Goal
Defenders tackle the ball carrier with a tackle input. A tackle (or the carrier running out of bounds) blows the play dead and records the spot.

## How Gridiron does it
"Feel every snap, block, pass, and tackle." Skill-based timing.

## Options
1. Contact = tackle (touch football). No skill.
2. **Committed dive tackle:** pressing tackle launches a short dive (0.35 s at 11 yd/s) in the facing direction. Touching the carrier within 1.0 yd during the dive is a tackle. A miss leaves the diver on the ground for 1.0 s. **Picked.** It's timing + angles, with risk/reward.
3. Tackle meter / QTE. Breaks flow.

## Better than Gridiron
Whiffing has a real cost (on the ground for 1 s), so pursuit angles and patience matter. Ball carriers can juke a diving defender.

## Rules
- Only defenders' tackles count, and only during LIVE.
- Can't start a dive while diving or recovering.
- A carrier tackled → phase DEAD, ball DEAD at the carrier spot, `dead_ball_spot`, "tackle" event (+ "whistle").
- A carrier out of bounds (outside the field lines) → DEAD, "out_of_bounds" event.
- The QB can be tackled behind the line (sack).

## Placeholder AI (moved into sim/ai.gd, the base for A14 bots)
- Offense skill players run go routes.
- Defenders hold for the first 2.5 s (coverage placeholder), then pursue the carrier; once a pass is caught, they pursue immediately. They dive when within 2.0 yd.

## Acceptance criteria
- A defender diving into a nearby carrier tackles: DEAD + spot + event.
- A dive that misses → no tackle, the diver can't move for RECOVER time.
- Offensive players' dives never tackle.
- Can't re-dive while diving/recovering.
- A carrier running out the sideline → DEAD with "out_of_bounds".
- A sack: the QB holding the ball behind the LOS can be tackled.
- AI defenders pursue and tackle a stationary carrier.
- Game flow: catch → AI pursuit → tackle → DEAD.
