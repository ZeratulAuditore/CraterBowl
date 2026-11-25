# 023: Leaderboards (A22)

## Goal
Per-position top-100 leaderboards built from match stats, persisted to disk (local/file-backed first).

## How Gridiron does it
"Extensive stats system with a public leaderboard for every position (top 100 player)."

## Design
- `src/sim/leaderboard.gd`: career lines per **player|POSITION** (games + summed stat fields); bots excluded. A position score ranks players:
  - QB: pass yds + 20·pass TD − 25·INT thrown + rush yds + 20·rush TD
  - WR: rec yds + 20·rec TD + 2·rec
  - RB: rush yds + rec yds + 20·(rush TD + rec TD)
  - C/OL: 2·blocks + 5·games
  - LB/CB/S/DL: 10·tkl + 25·sack + 40·int + 10·pbu + 25·ff + 25·fr
  `top(pos, 100)` sorted by score (ties → fewer games first), `rank_of(player, pos)`.
  JSON persistence (`save(path)` / `load(path)`), default `user://leaderboard.json`.
- Stats gains `blk` (block engagements by the blocker), so linemen rank on something real.
- The host (or offline player) records the match at FINAL; the final HUD shows your rank for each position you played.
- `-- --leaderboard[=POS]` prints the tables to stdout and quits.

## Options
1. An online leaderboard service. Infra; later (needs accounts/anti-cheat).
2. **Local file on the host machine** (picked). For a friend group the host is the league office; later it can sync to a service.

## Better than Gridiron
Linemen get a leaderboard too, via blocks.

## Acceptance criteria
- Scores match the formulas; two matches merge (games 2, sums add).
- Bots never appear; `top` is sorted and capped at 100.
- Save → load round-trip equal; a missing file loads empty.
- rank_of finds you; unknown → -1.
- Flow: real match final → leaderboard file has "You|QB" and the HUD shows "#1 QB".
