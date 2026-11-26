# Rules (classic)

Feature-level doc: how this works for players **today** on `main`. Open work: GitHub issues labelled `area:rules` (listed below).

## Summary
Classic Crater Bowl is two-way football with four downs to gain 10 yards, play-based tries instead of kicks,
and two timed halves. There is no kicking game yet: every "kickoff" places the receiving team at 25% of the
field. Fields shrink with match size so 3v3 and 5v5 use the same rules engine as 7v7.
Chaosball changes most of this: see [chaosball.md](chaosball.md).

## How it plays

### Match sizes and field scaling (`src/sim/match_config.gd`, `src/sim/roster.gd`)
| Size | Slots per team (offense/defense) | Field (length × width) | End zones | Kickoff spot | Timeouts per half |
|---|---|---|---|---|---|
| 3v3 | QB/LB, WR/CB, WR/CB | 60 × 30 | 8 yd | own 15 | 2 (`SMALL_MATCH_TIMEOUTS`) |
| 5v5 | + RB/S, C/DL | 80 × 40 | 10 yd | own 20 | 3 (`TIMEOUTS_PER_HALF`) |
| 7v7 | + OL/DL, OL/S | 100 × 53.33 | 10 yd | own 25 | 3 |

- Every athlete plays both ways; roles swap on change of possession. Formation x offsets scale with field width.
- 3v3 has no center: the QB holds the ball pre-snap and Space goes straight to a live play.
- The first down (10 yd) and the try distances (3 and 10 yd) do **not** scale with field size.
- Unknown sizes fall back to 7v7. Host picks 3/5/7 in the private lobby; offline via "Play vs bots".

### Downs and spotting (`src/sim/downs.gd`, `src/sim/match.gd`)
- 1st & 10 from the spot; "& Goal" when the line to gain would reach the goal line.
- The ball is spotted where the carrier is at the whistle (tackle or stepping out of bounds), clamped to
  the 1 and the opponent's 1. An incompletion returns to the line of scrimmage. No forward-progress rule.
- Four downs; failing on 4th is a turnover on downs, new offense at the mirrored spot (`goal − spot`).
- Snap: Space by any offensive human. If nobody snaps, the 20 s play clock (`Clock.PLAY_CLOCK`) auto-snaps.
- Next play starts `NEXT_PLAY_DELAY` (2.0 s) after the whistle; R skips the wait (offline or host only).

### Scoring and tries
| Event | Points | Then |
|---|---|---|
| Touchdown (carrier in bounds in the scoring end zone) | 6 (`TD_POINTS`) | scoring team attempts a try |
| Try for 1 (snap from the 3) | 1 | kickoff to the other team |
| Try for 2 (snap from the 10) | 2 | kickoff to the other team |
| Safety (offense's own carrier downed or out behind its goal line) | 2 to the defense (`SAFETY_POINTS`) | the defense receives |

- During try pre-snap the offense presses **1** or **2** (gamepad D-pad left/right); default is 1. A try is one
  untimed scrimmage play: a touchdown by the trying team scores, anything else (including a defensive return) is no good.
- A defensive touchdown (return of an INT or fumble) scores 6 for the defense, which then attempts the try.

### Turnovers
- **Interception:** a defender squarely at the ball (`INT_RADIUS` 0.6 yd) with no offensive receiver in reach.
  Within normal reach (`CATCH_RADIUS` 1.2 yd) he only breaks it up; a contested ball (defender within
  `CONTEST_MARGIN` 0.35 yd of the receiver's distance) is a breakup. The play stays live for the return.
- **Fumbles:** a dive tackle can strip the carrier. Risk grows with closing speed and the carrier's fatigue
  (no fumble while stamina ≥ 84%, except the rear strip); a sprinting carrier hit from behind (`FUMBLE_BEHIND_DOT`) is stripped 97% of
  the time. The roll uses a seeded RNG, so matches stay deterministic. The ball bounces and rolls
  (`LOOSE_FRICTION`, `LOOSE_BOUNCE`); the nearest standing player within `RECOVER_RADIUS` (0.8 yd) of a low ball recovers.
  A loose ball out of bounds is dead where it crossed and stays with the team that last had it.
- After a takeaway the new offense starts at the mirrored spot; downed in its own end zone = touchback at the kickoff spot.

### Clock (`src/sim/clock.gd`)
- Two halves, 5:00 each by default (`HALF_LENGTH`); private lobbies offer 2, 5 or 8 minutes (host key H).
- The game clock runs during live plays. It **keeps running between plays** only after an in-bounds tackle by the
  original offense short of the line to gain, before 4th down, with no change of possession. Incompletions,
  sideline stops, first downs, scores, turnovers and tries stop it.
- **One-minute warning**, once per half: a live play finishes first; a crossing between plays stops the clock at 1:00.
- **Timeouts:** U, outside live play, by either team; the scorebug shows pips. Resets the play clock if pre-snap.
  Counts reset at halftime. No gamepad binding.
- A half can end between snaps if the running clock hits 0:00. A play in progress at 0:00 finishes, and a touchdown on it still gets its try.
- Halftime: the team that did not receive the opening possession receives. HOME always receives first (no coin toss).
- After half 2 the higher score wins; a tie stands (no overtime).

## Design decisions
- Offense-frame yards (0 = own goal line, `goal` = field length) keep every rule direction-free; the view mirrors the field.
- Play-based tries (1 from the 3, 2 from the 10) instead of kicks: reuses the scrimmage engine and gives a real choice.
- Play-clock expiry auto-snaps, so an AFK player can't stall a lobby.
- The clock first ran only during live plays (iteration 009) for predictable pacing; iteration 034 added the running
  clock after short in-bounds tackles so reaching the sideline matters. Timeouts reuse existing dead-ball phases
  instead of a separate timeout state.
- Iteration 014 described fumbles as deterministic "sprint from behind only"; the code now uses a stamina/impact
  risk with a seeded RNG (the rear-strip case is still near-certain).

## Code and tests
- `src/sim/match.gd` — series flow: scoring, tries, kickoffs, turnovers, safeties, halves, timeouts.
- `src/sim/downs.gd` — downs, line to gain, spot clamping, down & distance label.
- `src/sim/clock.gd` — game/play clock, one-minute warning, timeout counts.
- `src/sim/world.gd` — whistles (tackle, out of bounds, touchdown), catches/interceptions, fumbles and loose balls.
- `src/sim/match_config.gd`, `src/sim/roster.gd`, `src/sim/field.gd` — sizes, slots, field geometry.
- `src/net/lobby.gd` (size/half settings), `src/net/protocol.gd` (host-validated `try`/`timeout` actions).
- Tests: `tests/test_downs.gd`, `tests/test_scoring.gd`, `tests/test_match.gd`, `tests/test_clock.gd`,
  `tests/test_turnovers.gd`, `tests/test_tackling.gd`, `tests/test_match_sizes.gd`, `tests/test_field.gd`, `tests/game_flow.gd`.

## History
- 007 [Downs](../iterations/007-downs.md)
- 008 [Scoring](../iterations/008-scoring.md)
- 009 [Match flow](../iterations/009-match-flow.md)
- 014 [Interceptions + fumbles](../iterations/014-turnovers.md)
- 016 [Match sizes](../iterations/016-match-sizes.md)
- 017 [Private matches](../iterations/017-private-matches.md) (half length setting)
- 034 [Running clock and timeouts](../iterations/034-clock-management.md)

## Open issues
- #4 C04b Four-quarter format and configurable periods
- #6 C04c Switching ends, mercy rule and clock actions
- #7 C05 Competitive rules: eligibility, grounding, blocking zone, QB slowdown
- #8 C06 Spotting: forward progress, return yards, fumble variety
- #16 B10 Overtime for tied games
- #39 B08 Tuning data file editable without code
- #40 C25 Momentum / "on fire"
- #42 C27 Backyard rules / trick plays
