# 006: Blocking (A06)

## Goal
Bodies collide, and offensive players can engage defenders in blocks that slow and steer them, so linemen can protect the QB and open lanes.

## How Gridiron does it
"Snap, block, pass, tackle." Line play is part of the core loop.

## Options
1. Godot physics bodies pushing each other. Non-deterministic, and it fights the sim/server split.
2. **Sim circles + engagement pairs.** Every standing athlete is a 0.45 yd circle; overlaps are separated (equal push). A non-carrier offensive player facing (dot > 0.3) a defender within 1.0 yd engages him. While engaged, the defender's displacement is 70% the blocker's and 30% his own. The engagement holds for 1.5 s, then the defender sheds and is immune to new blocks for 0.75 s. **Picked.**
3. Rock-paper-scissors line minigame. That's Phase B (B01), deliberately later.

## Better than Gridiron
Timed shed + immunity window means a block buys a fixed, readable amount of time. You don't get a permanent wall or a paper-thin one.

## Rules / details
- After a shed, the beaten blocker can't re-engage for 1.5 s, longer than the defender's 0.75 s immunity (found in testing: a lone C could re-block one LB forever).
- Grounded (dove) athletes don't collide.
- Carriers can't block. Blocks only form during LIVE.
- Neutral zone is still enforced presnap, after collisions.

## AI
- DL rush the carrier immediately at the snap; other defenders keep the 2.5 s hold.
- OL/C pass-protect: step toward the nearest rushing defender, staying between him and the carrier.

## Acceptance criteria
- Two athletes overlapping are separated to ≥ 0.9 yd.
- A grounded athlete is ignored by collision.
- An OL facing a DL in contact engages; the engaged DL moves much less toward his goal than a free DL.
- Engagement breaks after BLOCK_HOLD, and immunity prevents an immediate re-engage.
- A ball carrier never engages.
- AI: with 2 OL + C protecting, a DL rush takes longer to sack the QB than with no protection.
- Game flow: earlier steps still pass with DL rushing immediately (protection holds long enough to throw).
