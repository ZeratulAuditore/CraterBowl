# 020: Chaosball (A19)

## Goal
A 3v3 arcade variant: low gravity, anyone can throw or catch at any time (including their own pass), and passes stay live through up to 3 bounces off the ground or walls.

## How Gridiron does it
Chaosball (3v3): anyone can catch and throw at any point; the ball can bounce off ground/walls up to 3 times before a pass is incomplete; you can catch your own passes; low gravity. (Pass-streak scoring + exploding pass clock: A20.)

## Design
- **Ruleset on World** (`set_ruleset("chaosball"|"classic")`): `gravity` 0.45×, `anyone_throws` (any holder, anywhere, unlimited passes per play), `self_catch`, `max_bounces` 3, `walls` (sidelines + back lines reflect the ball). The pass solver/lead/arc preview take gravity as a parameter, so aiming stays exact in low gravity.
- **Ball:** each ground/wall contact = 1 bounce (restitution 0.55 vertical, 0.8 horizontal). The 3rd bounce kills it → incomplete. Catchable between bounces.
- **Catches:** no breakups; the nearest player within reach catches. An opponent catch is an interception and the play continues live (possession swings).
- **Flow (Match):** in Chaosball, each possession is a single live play. A touchdown scores (6 for now; streak scoring in A20). Any tackle, OOB, or incomplete is a **turnover** to the team that didn't have it, at the spot.
- Mode selection: `-- --mode=chaosball` (forces 3v3); lobby setting `mode` (classic/chaosball).
- AI: in Chaosball any AI carrier passes to its most open teammate ahead when pressured, and ball-chasers use the low-gravity landing prediction.

## Better than Gridiron
Aim assist stays exact under low gravity because the solver knows the ruleset. The arc preview shows the real floaty trajectory.

## Acceptance criteria
- Low gravity: the same throw stays in the air longer and the aim point is still hit.
- QB can throw past the LOS; a second pass in the same play works.
- Self-catch: a lob ahead, the thrower runs under it → caught by the thrower.
- Bounces: catchable after 1 bounce; incomplete on the 3rd.
- Walls: a ball thrown at the sideline reflects back in bounds.
- Opponent catch → possession swings, still LIVE.
- Match: incomplete → turnover to the non-throwing team; tackle → turnover; TD → +6 and kickoff.
- A Chaosball all-bot game runs with no stuck plays.
