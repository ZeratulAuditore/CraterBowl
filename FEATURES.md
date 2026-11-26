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
- [x] A07 Downs: line of scrimmage, 4 downs, first-down line, turnover on downs
- [x] A08 Scoring: touchdown, extra point/2pt, safety, kickoff/possession reset
- [x] A09 Match flow: game clock, halves, play clock, halftime, end of game
- [x] A10a Networking core: protocol, host/join over ENet, server-authoritative sim, client input → snapshots
- [x] A10b Netcode feel: client-side prediction for own athlete + snapshot interpolation for others
- [x] A11 Teams + positions: 7v7 rosters, position select (QB, C, WR, RB, LB, CB, S), team swap
- [x] A12 Routes + play calling: pre-snap route selection, real-time route coordination for receivers
- [x] A13 Interceptions + fumbles: turnovers during live play
- [x] A14 Bots: AI fills empty slots for offense and defense
- [x] A15 Match sizes: custom matches 3v3, 5v5 and 7v7 (field scaling + roster rules)
- [x] A16 Private matches: lobby with host settings, invite code, ready-up
- [x] A17 Offline practice mode: solo vs bots, drills
- [x] A18 Casual + competitive queues: matchmaking (local queue service stand-in first)
- [x] A19 Chaosball 3v3: low gravity, anyone can throw/catch, catch your own pass, up to 3 bounces off ground/walls
- [x] A20 Chaosball scoring: pass streak raises TD value (cap 7), pass clock that explodes the ball
- [x] A21 Stats: per-player, per-position stats tracked each match, end-of-match summary
- [x] A22 Leaderboards: per-position top 100 (local/file-backed first)
- [x] A23 Ranked: skill rating, rank tiers, seasons with season rewards; competitive hosts apply the matchmaker's snake-draft teams (computed in A18, not yet applied)
- [x] A24 Cosmetics: earnable through play, no gameplay effect, character customization
- [x] A25 Replays: record + playback of matches/plays
- [x] A26 Presentation (built by the graphics session, merged 1868056): original sci-fi lunar stadium, animations, lighting pass
- [x] A27 Menus/HUD/settings (out-of-game session; see docs/OUT_OF_GAME.md): main menu, Esc overlay, gamepad + controls rebinding (translation layer in src/ui/controls.gd), audio/video settings. Gap: right-stick aiming
- [x] A28 Parity audit (PASS 2026-11-25, iter 031 — `./scripts/parity_audit.sh`): walk this list end to end in a built game, file bugs as new items

## Phase B: Better than Gridiron (from PLAN.md)
- [ ] B01 Line play minigame (leverage/hand-fighting timing)
- [ ] B02 DB press/jam mechanic
- [x] B03 Play-card huddle (5s, 6–8 plays per side)
- [x] B04a Play replays: play summaries + highlight tags, auto highlight replay (offline), replay cameras, in-match transport (pause/frame/plays/highlights/speed), highlight reel at FINAL, replay overlay
- [ ] B04b Highlights, part 2: online auto TD replay with a skip vote, free-cam replay theater, clip export (frame range → image sequence/video), auto-replay toggle in Settings
- [ ] B05 Friend-group seasons + persistent stats
- [ ] B06 Juice: hit-stop, screenshake, crowd stingers
- [~] B07 Steam relay / NAT traversal (out-of-game session): UPnP + public-IP invite codes + server browser DONE; relay for CGNAT + hosted public matchmaker pending (needs user decision, docs/OUT_OF_GAME.md)
- [ ] B08 Tuning data file (TUNING) editable by designers without code
- [~] B09 Real kickoffs + returns (claimed: claude 2026-11-25, with C02; branch kicking-game) (A08 uses an automatic touchback)
- [ ] B10 Overtime (sudden death or alternating possessions) for tied games

## Phase C: Gap backlog (docs/gaps/TODO.md)
After Phase B, take the first unchecked `C##` item in `docs/gaps/TODO.md` (P0 → P1 → P2) and check it off there. The list comes from a gap analysis against Gridiron's patch-note mechanics and the arcade-sports genre (`docs/gaps/GAP_ANALYSIS.md`), and a scheduled job (`tools/gap_review.sh`) re-evaluates it. P0 items C01–C10 (run game, kicking, moves, clock, competitive rules, defense calls) are real Gridiron mechanics that the A-list missed.

## Discovered (bugs/follow-ups the loop adds here; fixed before new features)
- [x] D02 Party queue: friends queue together and land in the same match/team (matchmaker backend + CLI; menu UI belongs to the out-of-game session) — parity G09
- [x] D03 Chaosball in matchmaking: queue mode for Chaosball 3v3 — parity G17
- [x] D04 Achievements: milestone unlocks (first TD, 300-yd game, pick-six, 7-pt Chaosball TD, …) with profile persistence — parity G23
- [ ] D05 Stats: return yards after interceptions/fumble recoveries (gap noted in A21)
- [x] TRN Training ground (user request 2026-11-25): hub with 3 portals (blocking / practice field / catching), leveled drills + personal bests, and the queue waiting lobby (warm up while matchmaking). See docs/TRAINING.md
