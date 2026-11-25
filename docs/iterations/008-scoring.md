# 008: Scoring (A08)

## Goal
Touchdowns, conversion tries, safeties, and a possession reset after scores.

## How Gridiron does it
7v7 American football; scoring by touchdown. (Gridiron's Chaosball has its own streak scoring, A20.)

## Design
- **Touchdown (World):** the ball carrier is inside the opponent end zone (offense-frame y > 100) and in bounds while LIVE → "touchdown" whistle. This covers runs and catches in the end zone.
- **Safety (Match):** the carrier is downed or out of bounds with spot y < 0 → 2 points to the defense.
- **Try (Match):** after a TD, one scrimmage play. 1 point from the 3, or 2 points from the 10 (7v7 arcade: no kickers). Success = touchdown on the try. Choose with 1/2 during try presnap (default 1).
- **Kickoff (simplified):** after any score, the team that didn't just score (or, after a safety, the team that did) receives at its own 25. Either way, it's the current defense. A real kickoff return could come later; it's logged as a Phase B idea.

## Options
1. Kick-based PAT. Gridiron has no kicking game, and it adds a whole subsystem.
2. **Play-based tries** (picked). They reuse the scrimmage engine, which is exciting and cheap.

## Better than Gridiron
The choice of 1 from the 3 or 2 from the 10 gives a real risk/reward decision on every touchdown.

## Acceptance criteria
- A carrier running into the end zone → touchdown, +6, try state.
- A pass caught in the end zone → touchdown.
- Being tackled in your own end zone → safety, +2 defense, the defense receives at its 25.
- A successful try adds 1 or 2 (by choice); a failed try adds 0. Either way, a kickoff to the other team at its own 25, 1st & 10.
- Try LOS: 97 for 1 point, 90 for 2 points.
- Game: scoreboard on the HUD, 1/2 keys choose the try; flow: forced TD → score → try → kickoff.
