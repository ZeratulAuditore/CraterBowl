# 029: Chaosball in matchmaking (D03, parity G17)

## Goal
Players can queue for Chaosball, not just open private Chaosball lobbies.

## Design
Queue entries gain `game` (classic | chaosball; Chaosball forces size 3). The matchmaker forms matches per (game, mode, size), so the games never mix. The host order carries `game`, and the elected host opens its lobby in Chaosball mode. CLI: `--queue=casual|competitive --mode=chaosball` (the menu UI belongs to the out-of-game session). Works with parties (D02).

## Acceptance criteria
- A Chaosball entry is forced to 3v3; classic and Chaosball never match together; an unknown game is rejected.
- Integration: two `--mode=chaosball` queuers → "NET match started: Chaosball 3v3".
