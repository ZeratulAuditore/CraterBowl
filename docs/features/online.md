# Online play

Feature-level doc: how this works for players **today** on `main`. Design/implementation detail: [../design/netcode.md](../design/netcode.md), [../design/architecture.md](../design/architecture.md). Open work: GitHub issues labelled `area:online` (listed below).

## Summary
One player hosts (listen server, ENet/UDP). Everyone else joins with an invite code, an IP, the match browser, or by queueing on the matchmaker, which picks one queued player to host and sends the rest that host's code.
Bots fill every empty slot. Everything runs peer-hosted: there are no dedicated servers. Quick match, ranked and the browser all need a matchmaker, and the default address is `127.0.0.1:24600`, so they work only if someone runs one (#48).

## How it plays

### Ways in (menu: **Online** tab, or the home-screen PLAY selector)
| Path | What happens |
|---|---|
| Host a match | Opens a private lobby on UDP **24565** with the picked size/rules. "List publicly in the match browser" (on by default) advertises it. |
| Join | Type an invite code `XXXXX-XXXXX` or an IPv4 address. Anything else is rejected with a hint. |
| Open matches (browser) | List from the matchmaker, refreshed every 3 s; JOIN launches with that lobby's code. |
| Quick match / Ranked | Queue `casual` / `competitive` on the matchmaker for the picked size and rules, solo or as a party. |
| Home PLAY selector | Shortcuts: 3v3/5v5/7v7 quick match, 5v5 ranked (plus the offline modes). |

### Invite codes
- 10 Crockford base32 chars encoding IPv4 + port (`src/net/invite_code.gd`). Case-insensitive; `O`→0, `I`/`L`→1 are forgiven.
- The address inside is the router's public IP when UPnP succeeded, otherwise this PC's LAN address.

### Private lobby (in the match scene, text HUD)
- HUD: `PRIVATE MATCH LOBBY  Invite code: …`, settings, seats taken (`6/6 players`) and names (✓ = ready).
- **Enter** toggles ready. The host can press **3/5/7** for team size, **M** for classic/Chaosball, **Q** for halves/quarters and **H** for the duration. Defaults are 7v7 and five-minute halves. See [clock rules](rules.md#clock-srcsimclockgd) for the duration choices.
- Any settings change un-readies everyone except the host.
- Hosting from the menu with Chaosball selected opens a classic 3v3 lobby. Press **M** to switch to Chaosball (#74).
- Starts automatically when **every player is ready and at least 2 are present**. A host alone can't start a private match.
- **Seats are capped at the match size** (both teams' slots: 3v3 = 6, 5v5 = 10, 7v7 = 14 players, host included; #54). A joiner beyond that is turned away and their screen shows `COULDN'T JOIN THE MATCH` with the reason (`Lobby full: 3v3 seats 6 players`). Nobody waits in a lobby they can never play from. There are no spectators yet (#20).
- **The host can't shrink the match below the players already present.** Pressing 3/5 or M (Chaosball is 3v3) with too many players is refused, and the host lobby shows why (`Can't switch to 3v3: 7 players here, 6 seats. Someone has to leave first.`). Nobody is kicked. Growing the match is always allowed.
- Players who join after kickoff go straight into a free slot. With every seat taken they're turned away with `Match full: every seat is taken`. ENet allows at most 13 clients (14 humans, a full 7v7).

### Team and position online
- Humans are seated automatically: each joins the team with fewer humans and takes the first free slot in priority order (QB/LB, WR/CB, WR/CB, RB/S, C/DL, OL/DL, OL/S).
- Queue matches seat players on the matchmaker's team split, matched by name.
- Online players keep their host-assigned athlete during the match. Pre-match role preferences and QB voting are tracked in #18.

### Queues (`src/net/matchmaker.gd`)
| Rule | Casual | Competitive (Ranked) |
|---|---|---|
| Match formed when | both teams full, or ≥ 2 players after **8 s** | same, after **15 s**, within the rating window |
| Rating window | none | ±(100 + 25 × seconds waited), max ±600, around the longest-waiting unit |
| Sizes | 3v3 / 5v5 / 7v7, never mixed | same |
| Rules | classic or Chaosball (Chaosball always 3v3), never mixed | same; a competitive Chaosball queue exists and uses the same rating |

- The host is the first member of the longest-waiting unit. They open a lobby with 5-min halves and auto-ready, and the match starts only when **all** matched players have joined. Joiners auto-ready.
- Team split for every queue match: biggest units first, each onto the team with fewer players (tie: lower rating total).
- Your queue rating is the one in your own `user://ranked.json` (see [progression.md](progression.md)).
- While you wait you free-roam the training ground, with the title `SEARCHING FOR A CASUAL MATCH m:ss` ([training.md](training.md)).

### Parties
- Online tab → Party: Solo or 2–7, plus a 5-char code (**New code** generates one). Every member picks the same size, rules and code, then queues.
- A party waits until all members have queued, is never split across teams, and must fit on one team (party size ≤ team size). Otherwise the matchmaker refuses the enqueue.

### Match browser (`src/ui/server_browser.gd`, `src/net/lobby_registry.gd`)
- Row: `<name>'s match · 5v5 CLASSIC · 3/10 · IN PROGRESS`. JOIN is disabled when full.
- Order: open lobbies before in-progress ones, then not-full before full, then by player count. At most 50 rows.
- A public host re-registers every 5 s, and an entry disappears 20 s after its last refresh.
- No connection within 4 s shows "Matchmaker … is offline", and hosting/joining by code still work.

### UPnP (`src/net/port_mapper.gd`)
- Settings → Online → "Open my router port automatically when hosting (UPnP)", on by default.
- Before hosting (24565) or queueing (24566, so any queuer can be elected host), the game asks the router to forward the UDP port. The lease is 4 h, and the mapping is not removed on exit.
- A private or carrier-grade NAT external IP (100.64/10) counts as a mapping failure. The code uses the LAN address, and the host lobby shows the failure and the UDP port to forward (#47).

### Disconnects
- **A client leaves (host side):** in the lobby they're removed. In a match their slot is released and a bot plays that athlete for the rest of the match.
- **Host leaves or crashes:** clients get no message or menu return. Snapshots stop, the match freezes, and players must use Esc → Leave match. There is no reconnect or host migration (#17).
- **Esc menu online:** the match keeps running (no pause). Leave match closes the connection.
- **Bad code / unreachable host / unreachable matchmaker:** no timeout or error. The client stays in its waiting lobby or on the training ground until the player leaves.

## Design decisions
- **A menu choice is a CLI launch** (`{"host": true}` == `--host`), so the menu runs the same paths `net_test.sh`/`mm_test.sh` cover ([out-of-game.md](out-of-game.md)).
- **Peer-hosted, matchmaker only brokers.** The matchmaker never carries game traffic. That keeps hosting free but leaves CGNAT players unable to host (#32, #21).
- **Invite code = address.** No server is needed to resolve codes. The downside is that a code changes whenever the host's IP or port does.
- **Queue matches start only with the full matched group** (`Lobby.expected`), so no one is seated by a bot because they joined late.
- The iteration 019/024 notes describe a rating "snake draft". The code now uses the party-aware `unit_teams`, and `snake_teams` is unused outside tests.

## Code and tests
- `src/net/net_session.gd`: ENet host/join, seat assignment, lobby relay, disconnect → release.
- `src/net/lobby.gd`: lobby state, ready rules, host-only settings.
- `src/net/invite_code.gd`: code ⇄ IP:port.
- `src/net/matchmaker.gd`: queue rules, parties, team split. `src/net/mm_server.gd` / `src/net/mm_client.gd`: matchmaker process and client.
- `src/net/lobby_registry.gd`, `src/net/lobby_advertiser.gd`, `src/ui/server_browser.gd`: match browser.
- `src/net/port_mapper.gd`: UPnP. `src/sim/roster.gd`: slots, auto-assign.
- `src/game/main.gd` (`_host_game`, `_join_game`, `_queue_up`, `_step_lobby`, `_start_from_lobby`) and `src/ui/main_menu.gd` (`_screen_online`, `_queue`, `host_match`, `_with_port`).
- Tests: `tests/test_lobby.gd`, `tests/test_matchmaker.gd`, `tests/test_protocol.gd`, `tests/test_roster.gd`, `tests/test_out_of_game.gd` (registry, advertiser, public-IP check), `tests/net_host.gd` + `tests/net_client.gd` via `scripts/net_test.sh`, `scripts/mm_test.sh` (`MODE=casual|competitive|party|chaos`), `tests/menu_flow.gd`.

## History
- 010 [Networking core](../iterations/010-networking-core.md)
- 011 [Netcode feel](../iterations/011-netcode-feel.md)
- 012 [Teams + positions](../iterations/012-teams-positions.md) (its online team/position actions no longer exist)
- 016 [Match sizes](../iterations/016-match-sizes.md)
- 017 [Private matches](../iterations/017-private-matches.md)
- 019 [Casual + competitive queues](../iterations/019-queues.md)
- 028 [Party queue](../iterations/028-party-queue.md)
- 029 [Chaosball in matchmaking](../iterations/029-chaosball-queue.md)
- 031 Parity audit: merged UPnP, public matchmaker and match browser from the out-of-game session ([ITERATIONS.md](../../ITERATIONS.md))

## Open issues
- #14 C32 Co-op vs bots playlist + bot difficulty
- #17 C11 Reconnect, leavers, forfeit
- #18 C12 Position assignment: QB vote, role preferences
- #20 C14 Spectators
- #21 C15 Find a game without port-forwarding: dedicated server + browser
- #26 C20 Rematch and keep-the-lobby
- #27 C21 Host tools: mutators, ref console, kick/mute
- #28 C22 Trustworthy progression
- #29 C23 New-player protection
- #32 B07 NAT relay for CGNAT/strict routers + hosted public matchmaker
- #44 C29 Events and variety: weather, time of day, rotating modes
- #48 Decide: host the public matchmaker (VPS/AWS + DNS)?
- #56 Client doesn't detect losing the host
- #57 UPnP port mapping is never removed after hosting
- #58 Dead matchmaker code: whoami/you path and snake_teams
- #59 Competitive team seating is keyed by display name
- #74 Private host lobby ignores the menu's Chaosball selection
- #75 Stadium screen shows a running-match clock in the private lobby
