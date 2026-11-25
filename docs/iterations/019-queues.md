# 019: Casual + competitive queues (A18)

## Goal
Players queue for casual or competitive matches and get placed into a game automatically.

## How Gridiron does it
"Casual and competitive online matches (7v7)" with matchmaking; private matches are separate (A16).

## Design (peer-hosted games, central queue)
- `src/net/matchmaker.gd` (pure rules):
  - **Casual:** per size, full teams (2×size) first come first served; after 8 s waiting, start with ≥ 2 humans (bots fill the rest).
  - **Competitive:** per size, rating window around the oldest entry = ±(100 + 25/s waited, cap 600); full teams if possible, else after 15 s any ≥ 2 within the window. Teams by **snake draft on rating** for balance.
  - Each match: mode, size, players, host (the longest-waiting player), teams.
- `src/net/mm_server.gd` (Node): `-- --matchmaker [--port]` runs a headless queue server. On a match it tells the host `{"role":"host", settings, expected}`, waits for the host's invite code, then sends `{"role":"join", code}` to the others. Disconnect = dequeue.
- `src/net/mm_client.gd` (Node) + main: `-- --queue=casual|competitive --mm=ADDR[:PORT] [--size] [--rating]`. Host role → open a lobby on a free port, auto-ready, auto-start when `expected` players have joined, report the code. Join role → join by code, auto-ready.
- Lobby gains `expected` (auto-start only once that many players are present).

## Options
1. A dedicated-server fleet. Real infra, not for a friend group yet.
2. **Central queue + player-hosted matches** (picked). Reuses the A16 lobby/invite pipeline; the matchmaker is tiny and stateless beyond queues.
3. Pure P2P discovery. NAT pain; B07.

## Better than Gridiron
Bots let small queues still play (casual starts after 8 s with 2 people). Competitive teams are snake-drafted by rating, so stacked teams are rarer.

## Acceptance criteria
- Casual: 2×size queued → immediate match; 2 queued → nothing until 8 s, then a match; 1 queued → never.
- Competitive: ratings 1000 vs 1500 don't match early; the window widens and they match later; 1000 vs 1050 match after 15 s; snake draft balances team ratings.
- Mode and size never mix.
- Integration: matchmaker + 2 queued headless clients → one hosts, the other joins by code, the match starts with 2 humans.
