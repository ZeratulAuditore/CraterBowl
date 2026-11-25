# 012: Teams + positions (A11)

## Goal
Full 7v7 rosters where each human picks a team and a position, can change position between plays, and can swap teams.

## How Gridiron does it
7v7, one athlete per player, per-position stats/leaderboards. So players choose positions (QB, receivers, linemen, defense).

## Design
- `src/sim/roster.gd` (pure): for each team, 7 **slots** = two-way athletes with an offense/defense pairing:
  `QB/LB, C/DL, WR/CB, WR/CB, RB/S, OL/DL, OL/S`. Each slot is owned by a player id or is a bot (-1).
- `auto_assign(player)`: joins the team with fewer humans and takes the first free slot in priority order (QB/LB first, so the first human on each side gets the ball).
- `claim(player, slot)`: only if free (or already yours). `swap_team(player)`: moves to the free slot on the other team with the same pairing if possible, else the first free one.
- Offline: TAB cycles to the next free slot on your team, T swaps teams (only when not LIVE).
- Online: the server owns the Roster. Clients request `{"a":"pick","slot":i}` / `{"a":"team"}` (reliable); the server re-sends the assignment. NetSession delegates assignment to callables (`assign_fn` / `release_fn`).

## Options
1. Fixed assignment by join order (A10a's pool). No choice, which fails parity.
2. **Slot roster with claims** (picked). Simple, authoritative, easy to show in a lobby later (A16).

## Better than Gridiron
Position changes between plays without leaving the match, and empty slots are always AI, so no team plays a man down.

## Acceptance criteria
- auto_assign balances humans across teams and prefers QB/LB.
- claim fails on an occupied slot; release frees it.
- swap_team keeps the pairing if free, otherwise takes any free slot, and fails if the other team is full of humans.
- `humans()` lists owned athletes for AI exclusion.
- Net: client swaps team → reassigned to a team-0 athlete; picking the host's slot is rejected.
- Game: HUD shows your position; TAB/T work between plays.
