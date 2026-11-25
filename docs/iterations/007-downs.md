# 007: Downs (A07)

## Goal
Line of scrimmage, 4 downs to gain 10 yards, first downs, turnover on downs with possession change.

## How Gridiron does it
Standard American football downs in a 7v7 arcade package.

## Design
- `src/sim/downs.gd`: pure rules engine in **offense-frame yards** (offense always attacks +y, 0 = own goal line). `apply(result)` handles tackle/OOB spots and incompletions. It returns first_down, next_down, or turnover_on_downs; a turnover flips the spot to `100 - spot` for the new offense.
- `src/sim/match.gd`: owns World + Downs. It listens to the World's end-of-play events, records the result, and `next_play()` resets the formation at the new LOS (swapping offense on turnover).
- **Two-way athletes:** each athlete has an offense role/x and a defense role/x (e.g. QB↔LB, C↔DL). `World.set_offense(team)` swaps roles. This is required for possession changes and matches Gridiron's one-athlete-per-player model.
- Touchdowns/safeties are A08. Until then, spots clamp to [1, 99].

## Options considered
1. Absolute field coordinates with per-team direction. Every rule needs direction math, so it's error-prone.
2. **Offense-relative frame** (picked). Rules stay simple; the presentation mirrors the field visually.

## AI addition (needed so the opponent's offense works)
The AI QB throws a lead pass to the most open eligible receiver after 2.0 s (or when a rusher is within 3 yd).

## Better than Gridiron
The HUD shows down & distance plus LOS/first-down lines on the turf, so you always know the situation at a glance.

## Acceptance criteria
- Gain ≥ distance → 1st & 10 at the spot; "& goal" when the line would pass the goal line.
- Short gain → down+1, distance reduced; loss → distance increased.
- Incomplete → same LOS, down+1.
- 4th-down failure → turnover on downs: offense swaps, LOS = 100 − spot, 1st & 10.
- Match: a tackle → `next_play()` sets the World LOS to the spot, PRESNAP; a turnover swaps `world.offense_team` and roles (the new offense has a QB and C).
- The AI QB throws within ~2.5 s when unpressured.
- Game: HUD down & distance; LOS + first-down markers; auto next play 2 s after the whistle.
