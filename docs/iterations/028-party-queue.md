# 028: Party queue (D02, parity G09)

## Goal
Friends queue together and always land in the same match on the same team.

## Design
- Queue entries carry `party` (shared code) + `party_size`; `--party=CODE:SIZE` on the CLI (the menu UI is the out-of-game session's).
- The matchmaker forms **units**: solo players, or parties once every member has queued (incomplete parties wait). Casual FCFS / competitive rating window (party = average rating) operate over units; a unit is never split.
- Team split `unit_teams`: biggest units first, each onto the team with fewer players (tie: lower rating total), never exceeding the team size. A party bigger than a team is rejected at enqueue.
- A complete party alone still plays after the casual wait (co-op vs bots).

## Acceptance criteria
- An incomplete party never matches; a complete duo matches (same team).
- A 3-stack + 3 solos → full 3v3 with the stack together and the solos on the other team.
- A party larger than a team, or of size 1, is rejected.
- Competitive uses the party's average rating for the window.
- Integration: two clients with `--party=PALS:2` → seated on the same team.
