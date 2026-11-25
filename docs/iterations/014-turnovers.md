# 014: Interceptions + fumbles (A13)

## Goal
Turnovers during live play: defenders intercept passes, carriers fumble, loose balls get recovered, and possession flips with returns, pick-sixes and touchbacks.

## How Gridiron does it
A football game with defense "locking down opponents"; turnovers are core football.

## Design
- **Interception:** a defender alone within catch reach (no offensive player within reach) catches the ball. Both sides within the contest margin → breakup (A04 rule kept).
- **Possession team** = the carrier's team during live play. Tackles, blocks and TD direction use it: the original offense scores in end zone B (y > 100), a returning defender in end zone A (y < 0). Linemen-only blocking rules apply only to the original offense's pass play; on a return any teammate can block.
- **Fumbles, deterministic (no RNG):** a dive tackle on a **sprinting** carrier **from behind** (diver facing · carrier velocity dir > 0.5) strips the ball. The carrier is knocked down (0.8 s) and the ball goes LOOSE with half the carrier's momentum plus a hop, then bounces and rolls with friction. Any standing, non-diving athlete within 0.8 yd of a low ball recovers it (closest wins). A loose ball out of bounds → dead, the fumbling team keeps it at that spot.
- **Match:** results carry the carrier's `team`. Different from the offense → turnover, with the spot mirrored (`100 − y`); downed in your own end zone after a takeaway → touchback at 25. A defensive TD scores for that team, and they attempt the try. Safety only for the offense's own carrier.
- **AI:** everyone chases a loose ball; non-possession players pursue the carrier; the returner's teammates escort by moving to the nearest pursuer (blocks form on contact).

## Better than Gridiron
Fumbles are a skill rule, not luck: don't sprint when someone is closing from behind. It's readable and testable, and nobody loses a game to an invisible dice roll.

## Acceptance criteria
- A lone defender at the ball → "interception", the defender holds the ball, play stays LIVE.
- A contested ball → still "breakup".
- An intercepting defender tackled by an offensive player → Match turnover: the defender's team on offense at the mirrored spot, 1st & 10.
- A defender returning into end zone A → touchdown for the defense; try for the defense.
- INT downed in own end zone (y > 100) → touchback at 25.
- Sprinting carrier dove on from behind → "fumble", ball LOOSE, play LIVE; nearest player recovers → "recovery"; recovered by the defense then tackled → turnover.
- Head-on dive or non-sprinting carrier → normal tackle.
- Loose ball out of bounds → dead, the fumbling team keeps it.
- The AI chases a loose ball.
