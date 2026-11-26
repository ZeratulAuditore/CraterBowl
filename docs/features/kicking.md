# Kicking

Feature-level doc: how this works for players **today** on `main`. Design/implementation detail: [architecture](../design/architecture.md). Open work: GitHub issues labelled `area:kicking` (listed below).

## Summary
There is no kicking game on this branch. Nobody kicks the ball: a "kickoff" puts the receiving team 1st & 10 at 25% of
the field length, and points after a touchdown come from a one-play scrimmage try. There are no punts, field goals,
PAT kicks or coin toss. Real kickoffs and the kicking game are being built on other branches (#2, #3).

## How it plays

### Kickoff (placement only)
- `Match.kickoff_los()` = round(field length × `KICKOFF_FRACTION` 0.25), from the receiving team's own goal line:

| Match size | Field length | Receiving team starts at |
|---|---|---|
| 7v7 | 100 yd | own 25 |
| 5v5 | 80 yd | own 20 |
| 3v3 | 60 yd | own 15 |

- When it happens:
  - Opening play: team 0 (home) always receives. No coin toss.
  - Second half: the team that didn't receive the opening kickoff.
  - After a try (good or no good): the team that didn't try.
  - After a safety: the team that scored the safety.
  - Chaosball: after a touchdown the scored-on team gets the ball at the kickoff spot. No tries in Chaosball.
- There is no ball in the air, no return and no KICKOFF banner. The next formation simply lines up.

### Touchback
- A takeaway (interception or fumble recovery) downed in the taker's own end zone comes out to the kickoff spot.
  This is the only touchback in the game. See [rules.md](rules.md#turnovers).

### Tries (point after)
- After a touchdown the scoring team (offense or defense) lines up for a try. Choose during try pre-snap:
  **1** for 1 point from the 3 or **2** for 2 points from the 10 (`TRY_DIST`); gamepad D-pad left / right. Default is 1.
  Any player on the trying team may choose. The HUD shows `TRY FOR 1` / `TRY FOR 2`.
- The try is one untimed scrimmage play; the play clock still runs pre-snap. A touchdown by the trying team scores;
  anything else is no good, including a turnover returned for a score. Points table: [rules.md](rules.md#scoring-and-tries).
- Try distances don't scale with field size.

## Design decisions
- Play-based tries instead of kicks (008): reuse the scrimmage engine, and the 1-or-2 choice is a real risk/reward call.
- Simplified kickoff to the 25 (008): the reference game's live kickoff (power meter, tee, return alignments) was
  logged as B09, now #2. See [gap analysis](../research/gap-analysis.md).
- The kickoff spot scales with field size so small fields don't start teams near midfield.

## Code and tests
- `src/sim/match.gd` — `kickoff_los`, `_kickoff`, `choose_try`, `try_los`, TRY state, touchback and safety handling.
- `src/game/main.gd` — 1 / 2 keys. `src/game/overlay.gd` — `TRY FOR n` status.
- `src/net/protocol.gd` — host-validated `try` action (offense only, values 1 or 2).
- Tests: `tests/test_scoring.gd` (safety, tries good / failed / 2-point), `tests/test_turnovers.gd` (touchback),
  `tests/test_match_sizes.gd` (small fields), `tests/test_clock.gd` (untimed try, halftime kickoff), `tests/game_flow.gd`
  (TD, 2-point try, kickoff).

## History
- 008 [Scoring](../iterations/008-scoring.md)
- 009 [Match flow](../iterations/009-match-flow.md) (halftime kickoff)
- 014 [Interceptions + fumbles](../iterations/014-turnovers.md) (touchback)
- 016 [Match sizes](../iterations/016-match-sizes.md)

## Open issues
- #2 B09 Real kickoffs and returns
- #3 C02 Kicking game: coin toss, punts, field goals, PAT kicks
