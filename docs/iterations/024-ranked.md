# 024: Ranked (A23)

## Goal
Competitive matches change a skill rating; players climb rank tiers; quarterly seasons soft-reset ratings and grant season rewards. Competitive teams use the matchmaker's rating-balanced split.

## How Gridiron does it
"Climb the ranks…", ranked climbing, season-exclusive rewards.

## Design
- `src/sim/ranked.gd` (pure + JSON store `user://ranked.json`):
  - **Team Elo:** expected = 1/(1+10^((avgB−avgA)/400)); each player moves by K·(result − expected); K = 48 for the first 10 games (provisional), then 32. Ties = 0.5.
  - **Tiers:** Bronze <1100 ≤ Silver <1300 ≤ Gold <1500 ≤ Platinum <1700 ≤ Diamond <1900 ≤ Legend. (Our own names.)
  - **Seasons:** 3-month seasons, id = year·4 + quarter. On rollover each player's peak tier becomes a reward (`S<id>-<TIER>`, a cosmetic for A24), and the rating soft-resets halfway toward 1000.
  - Per-player record: rating, peak, games, wins.
- **Names:** `-- --name=NAME` (default "Player"). Sent in the queue request and to the host lobby (`name` lobby action), so lobby, stats and ratings use real names.
- **Competitive flow:** the matchmaker's snake-draft teams (by **name**) go to the host; at match start the host seats each lobby player on their assigned team (`Roster.auto_assign_team`). Private lobbies can opt in with `--ranked`.
- **Rating update** at FINAL of a ranked match (host): each human's team from the roster → Elo → save → broadcast `ranked` deltas. The HUD shows "RATING 1016 (+16) Silver".

## Better than Gridiron
Provisional K speeds up placement; soft resets keep seasons meaningful without wiping progress.

## Acceptance criteria
- Equal teams: the winner gains K/2 and the loser drops K/2; an upset gains more than an expected win; a tie between equals = 0.
- Provisional K (48) for the first 10 games, then 32.
- Tier boundaries correct.
- Season rollover: reward per peak tier, rating 1400 → 1200, games/wins reset.
- Store round-trip.
- Roster.auto_assign_team seats on the requested team (falls back if full).
- Flow: a ranked final updates the temp ranked file and the HUD shows the rating change.
