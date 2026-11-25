# 016: Match sizes (A15)

## Goal
Custom matches at 3v3, 5v5 and 7v7, each with a fitting field size and roster.

## How Gridiron does it
"Custom matches: from quick 3v3 battles to full 7v7 football"; marketing also lists 5v5.

## Design
- `src/sim/match_config.gd` (pure): size → slot count + field (length × width, end zone depth).
  3v3 = 60×30 (8-yd end zones), 5v5 = 80×40, 7v7 = 100×53.3.
- Roster: the first N slots of the priority list (3v3: QB/LB, WR/CB, WR/CB; 5v5 adds RB/S, C/DL; 7v7 adds OL/DL, OL/S). Formation x offsets are scaled to the field width.
- **No center (3v3): the QB starts with the ball** and the snap goes straight to LIVE.
- Downs/Match take `goal` = field length: mirrored turnovers (`goal − spot`), try LOS (goal − 3 / goal − 10), kickoff at 25% of the field, OWN/OPP labels around midfield. The first down stays 10 yd.
- Main: `-- --size=3|5|7` (lobby UI is A16), with a full in-place rebuild (`configure(size)`). The server's welcome carries the size, and a client with a different size rebuilds to match.

## Better than Gridiron
Fields scale with roster size, so 3v3 isn't a lonely 100-yd field. Every size uses the same rules engine.

## Acceptance criteria
- Configs: 3/5/7 slot counts and field dims; unknown size → 7.
- Roster(3) builds 6 athletes, no C, all inside the 30-yd width.
- No-C world: the QB holds the ball presnap; snap → LIVE with the QB still holding it.
- Downs(goal 80): & Goal when within 10 of 80; turnover mirrors 80 − spot; label "OPP 20" at 60.
- Match(60 field): TD past 60; try LOS 57 / 50; kickoff LOS 15.
- 3v3 and 5v5 all-bot games: plays complete, nothing stuck.
- Net: a client joins a 5v5 host and rebuilds to 10 athletes.
