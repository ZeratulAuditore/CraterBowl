Issue: #89 (Part of #6)

# 040 Switching ends

Teams switch the goal they attack every quarter. Gridiron and real football switch ends after Q1 and Q3 and again at halftime; the ball moves to the mirror spot so field position is kept.

#6 was too big for one iteration, so it was split: #89 switching ends (this), #90 host mercy rule, #91 spike and kneel.

## Options

- **Store an `ends` flag in Match and sync it.** Works, but adds snapshot and replay state for something the clock already implies.
- **Rotate the field/stadium node 180° when the offense attacks the "other" end.** The turf shader paints end zones by world position and the bowl is symmetric, so a rotation changes nothing visible; the end-zone names would also need re-facing.
- **Pick: derive it.** `Clock.period()` (0-based quarter, or half in the halves format) and `Match.defended_end(team) = team ^ (period odd)`. The sim is offense-relative (offense attacks +y), so field position, down and distance need no change at all. Presentation re-tints the end zones and swaps their names (`FieldArt.orient_ends`) whenever the offense or the period changes, and shows a SWITCH ENDS banner on a period change.

Better than Gridiron: the end-zone paint now also follows possession within a period, fixing #93 (NEBULA used to appear to defend the HELIOS end zone whenever it had the ball).

## Acceptance

- Each team defends the opposite end in Q2 and Q4 from Q1 and Q3; in the halves format the switch is at halftime. Quarter and halftime outcomes carry `switch_ends: true`.
- Possession, spot, down and line to gain carry over across Q1→Q2 and Q3→Q4.
- A client applying a host snapshot derives the same ends.
- The end zone behind the offense shows the paint and name of the end it defends; the real flow (Space snap, whistle, auto next play) lands in Q2 with the cues switched and a SWITCH ENDS banner.

## Not done here

Mercy rule (#90) and spike/kneel (#91).
