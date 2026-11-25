# 017: Private matches (A16)

## Goal
The host opens a private lobby, friends join with an invite code, the host picks settings, everyone readies up, and the match starts.

## How Gridiron does it
"Private matches" alongside casual/competitive queues; party up with friends.

## Design
- `src/net/invite_code.gd` (pure): IPv4 + port (48 bits) → 10 Crockford-base32 chars `XXXXX-XXXXX`, plus decode/validation. No matchmaking server needed; `--join=CODE` or `--join=IP` both work.
- `src/net/lobby.gd` (pure): phase LOBBY/IN_GAME; players {id: {name, ready}}; settings {size 3/5/7, half_minutes 2/5/8}; host-only settings changes, only in LOBBY; `all_ready()` = every player ready (including the host). Validated settings; full serialization for the wire.
- Server: `--host` opens a lobby by default (`--no-lobby` keeps the old instant start). Joiners are added to the lobby (no athlete yet), and lobby state is broadcast reliably on every change. Clients send `{"k":"lact"}` lobby actions (ready, name). When everyone is ready, the host starts: `configure(size)`, half length applied, every lobby player gets a roster slot and a welcome (with size). Late joiners go straight into the game.
- Keys in the lobby: Enter = toggle ready; host: 3/5/7 size, H half length. The HUD shows the code, settings and player ready states.
- `--start-when-ready` makes a headless host auto-ready (used by the net test).
- Clock: `half_length` is now per-match.

## Options
1. A relay/matchmaking server with short codes. It needs infrastructure; A18/B07 territory.
2. **Self-describing invite codes** (picked). Zero infrastructure, works on LAN / port-forwarded hosts.

## Better than Gridiron
Ready-up with live settings means nobody gets dropped into a half-loaded match, and the code is easy to read out on voice chat.

## Acceptance criteria
- Invite code round-trips 127.0.0.1:24565 and 203.0.113.7:65535; malformed codes rejected; ambiguous letters (O/I/L) accepted as 0/1/1.
- Lobby: add/remove; ready toggle; all_ready needs ≥2 players; non-host settings changes rejected; invalid size/half rejected; no changes IN_GAME.
- Clock half_length honored on reset and next half.
- Net test: host lobby (5v5) → client joins **by invite code**, sees lobby state, readies → match starts → client welcomed into 5v5 (existing checks follow).
