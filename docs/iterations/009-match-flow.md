# 009: Match flow (A09)

## Goal
Game clock, two halves, play clock, halftime, end of game with a winner.

## How Gridiron does it
Timed online matches (casual/competitive), so a match has a fixed length.

## Design
- `src/sim/clock.gd` (pure): HALF_LENGTH 300 s, 2 halves. **The game clock runs only during LIVE play** (arcade pacing that works online). The play clock is 20 s during PRESNAP.
- **Play clock expiry → auto-snap.** No delay-of-game griefing, and the pace stays high.
- **Untimed down:** a play in progress when the clock hits 0:00 finishes. A try after a touchdown at 0:00 is still played.
- When the clock is at 0 and the play/try is resolved: half 1 → halftime → half 2, and the team that didn't receive the opening possession gets the ball at its 25. Half 2 → FINAL, winner by score (ties stand; overtime logged as B10).
- Match owns the Clock; `Match.tick(dt)` advances the clocks and auto-snaps.

## Options
1. NFL-style running clock with stoppages. Needs complex rules, and a running clock between plays makes online games feel rushed.
2. **Live-play-only clock** (picked). Predictable 10–12 min matches.

## Better than Gridiron
The play clock auto-snaps instead of leaving a lobby waiting on an AFK player.

## Acceptance criteria
- The game clock decreases only while LIVE; the play clock only during PRESNAP and resets each play.
- The play clock reaching 0 snaps the ball.
- Clock at 0 during a live play: the play continues until the whistle.
- After a play ends with 0:00 in half 1 → "halftime", half 2 starts with the other team receiving at its 25 and the clock reset.
- After half 2 expires → "final" with a winner; `next_play()` is a no-op afterwards.
- A TD on the last play still gets its try before halftime/final.
- Game: HUD "H1 4:32 | PLAY 17"; final screen text; flow covers the auto-snap + halftime.
