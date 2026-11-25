# Feature Backlog

The daily loop takes the **first unchecked item**, ships it, tests it and checks it off. One item per iteration.

**Phase A is full parity with Gridiron** (Steam 708720 / Gridiron Remastered 3878710). We match mechanics and modes only. Name, art, UI, characters and audio stay 100% original.

Sources: Steam 708720, Steam 3878710, Gematsu "Gridiron Remastered" page (researched 2026-11-24).

## Phase A: Gridiron parity
- [x] A01 Field + player: regulation field with end zones, one third-person player with run/sprint/stamina and camera
- [x] A02 Ball + snap: ball entity, center snap to QB, ball possession state
- [x] A03 Precision physics passing: aim + charge throw, ballistic flight with leading
- [x] A04 Catching: catch radius/timing, contested catches, incompletions
- [x] A05 Tackling: tackle input, carrier down, whistle/dead ball
- [x] A06 Blocking: body collision, push/engage blocks at the line
- [ ] A07 Downs: line of scrimmage, 4 downs, first-down line, turnover on downs
- [ ] A08 Scoring: touchdown, extra point/2pt, safety, kickoff/possession reset
- [ ] A09 Match flow: game clock, halves, play clock, halftime, end of game
- [ ] A10 Networking core: host/join over ENet, server-authoritative sim, client input + prediction
- [ ] A11 Teams + positions: 7v7 rosters, position select (QB, C, WR, RB, LB, CB, S), team swap
- [ ] A12 Routes + play calling: pre-snap route selection, real-time route coordination for receivers
- [ ] A13 Interceptions + fumbles: turnovers during live play
- [ ] A14 Bots: AI fills empty slots for offense and defense
- [ ] A15 Match sizes: custom matches 3v3, 5v5 and 7v7 (field scaling + roster rules)
- [ ] A16 Private matches: lobby with host settings, invite code, ready-up
- [ ] A17 Offline practice mode: solo vs bots, drills
- [ ] A18 Casual + competitive queues: matchmaking (local queue service stand-in first)
- [ ] A19 Chaosball 3v3: low gravity, anyone can throw/catch, catch your own pass, up to 3 bounces off ground/walls
- [ ] A20 Chaosball scoring: pass streak raises TD value (cap 7), pass clock that explodes the ball
- [ ] A21 Stats: per-player, per-position stats tracked each match, end-of-match summary
- [ ] A22 Leaderboards: per-position top 100 (local/file-backed first)
- [ ] A23 Ranked: skill rating, rank tiers, seasons with season rewards
- [ ] A24 Cosmetics: earnable through play, no gameplay effect, character customization
- [ ] A25 Replays: record + playback of matches/plays
- [ ] A26 Presentation: original sci-fi lunar stadium, animations, lighting pass
- [ ] A27 Menus/HUD/settings: main menu, scoreboard HUD, gamepad + InputMap actions, controls rebinding, audio/video settings
- [ ] A28 Parity audit: walk this list end to end in a built game, file bugs as new items

## Phase B: Better than Gridiron (from PLAN.md)
- [ ] B01 Line play minigame (leverage/hand-fighting timing)
- [ ] B02 DB press/jam mechanic
- [ ] B03 Play-card huddle (5s, 6–8 plays per side)
- [ ] B04 Instant replay of last play + highlight clips
- [ ] B05 Friend-group seasons + persistent stats
- [ ] B06 Juice: hit-stop, screenshake, crowd stingers
- [ ] B07 Steam relay / NAT traversal
- [ ] B08 Tuning data file (TUNING) editable by designers without code

## Discovered (bugs/follow-ups the loop adds here; fixed before new features)
