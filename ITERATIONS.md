# Iteration Log

## 000: Scaffold (2026-11-24)
- Godot 4.3 project, headless unit-test runner (`scripts/test.sh`), smoke boot (`scripts/smoke.sh`), parity backlog, loop procedure.
- Tests: harness self-test only.

## 001: A01 Field + player (2026-11-24)
- Sim: `src/sim/field.gd` (regulation geometry, zones, playable clamp), `src/sim/player_motion.gd` (accel/decel, run 7 yd/s, sprint 9.5 yd/s, stamina drain/regen, exhaustion lockout until 25%), `src/sim/tuning.gd`.
- Game: procedural field (turf, end zones, 5-yd lines), capsule player (WASD + Shift), smoothed follow camera, stamina HUD.
- Better than Gridiron: exhaustion lockout makes sprint a decision.
- Tests: 13 unit passing; smoke boot 300 frames clean. `smoke.sh` allowlists one verified Godot 4.3 headless dummy-renderer message.
- Known gaps: keyboard only (no gamepad/InputMap yet; A27), no animation, camera doesn't collide.

## 002: A02 Ball + snap (2026-11-24)
- Sim: `world.gd` (authoritative World: athletes, ball, phase PRESNAP/LIVE/DEAD, formation, neutral-zone clamp, timed snap flight, events), `athlete.gd` (id/team/role), `ball.gd` (HELD/IN_FLIGHT/LOOSE/DEAD).
- Game: 7v7 athletes rendered in team colors; you control the QB; Space snaps, R resets; ball mesh follows sim; HUD shows phase.
- Tests: 19 unit passing (+6); smoke clean.
- Known gaps: non-controlled athletes stand still (bots in A14); no play end yet (A05).

## 003: A03 Precision physics passing (2026-11-24)
- Sim: `passing.gd` ballistic solver (bisection on launch angle to cross aim point at catch height; out of range → 45° falls short), `lead_target()` receiver prediction; World.throw (holder, LIVE, behind LOS, one forward pass), ball flight with gravity, ground = incomplete → DEAD. Throw-on-the-run inherits 30% of QB velocity.
- Game: mouse-aimed ground reticle, hold LMB/J to charge (0.9 s to full), release to throw, trajectory preview arc (better than Gridiron).
- Tests: 27 unit (+8). New `tests/game_flow.gd` scripted e2e through the real scene, wired into smoke.sh (7 checks).
- Known gaps: no catching yet (A04); D01 logged for gamepad/InputMap.

## 004: A04 Catching (2026-11-24)
- Sim: reach-volume catching (radius 1.2 yd, height window 0.3–2.6 yd, closest wins), defenders contest from radius + 0.35 yd margin → "breakup", out-of-bounds catch → incomplete, thrower can't catch own pass, **C/OL ineligible receivers** (found by tests: the C was catching flat passes over his head).
- Game: placeholder go routes for WR/RB after snap; control switches to the receiver on a catch; R resets control to QB.
- Tests: 34 unit (+7, one older passing test retargeted off the C's line); game flow 10 checks incl. real lead pass → catch → control switch.
- Known gaps: auto-catch only (catch/dive button later), defender "win" is a breakup until interceptions (A13).

## 005: A05 Tackling (2026-11-24)
- Sim: committed dive tackle (0.35 s @ 11 yd/s in facing dir, 1.0 yd reach; miss = 1.0 s grounded), `facing` on motion, whistle on tackle/carrier OOB → DEAD + `dead_ball_spot`, sacks behind LOS, `play_time`.
- `src/sim/ai.gd`: placeholder AI moved into the sim (go routes; defenders hold 2.5 s then pursue with lead + dive in range; pursue immediately after a catch). Base for A14 bots.
- Game: E / RMB dive, diving/grounded athletes lie flat, HUD shows whistle reason + spot.
- Tests: 41 unit (+7); game flow 13 checks (catch → AI pursuit → tackle → HUD reason). Flow caught a HUD ordering bug (generic whistle overwrote reason).
- Known gaps: no broken tackles/stiff-arm yet (could come with B06 juice), defense not human-playable until A11 team select.

## 006: A06 Blocking (2026-11-24)
- Sim: body circles (0.45 yd) with separation (grounded ignored); auto-engage blocks (blocker facing defender within 1.0 yd) → defender displacement 70% driven by blocker; 1.5 s hold then shed; defender 0.75 s immunity, beaten blocker 1.5 s cooldown. C/OL block anytime; skill players only block downfield (after catch / carrier past LOS).
- Formation now role-based depth + per-athlete `home_x` (bug found: second play kept drifted x from the previous play).
- AI: DL rush at snap; OL/C pass-protect (get between rusher and carrier); route runners sidestep defenders in their lane.
- Measured: full 7v7 pocket holds ~4.0 s before a sack.
- Tests: 51 unit (+10); test.sh now fails on leaked resources; game flow 13 checks pass with live pass rush.
- Known gaps: no player-driven shove/shed input (B01 line minigame), no run-blocking schemes until play calling (A12).

## 007: A07 Downs (2026-11-24)
- Sim: `downs.gd` (offense-frame rules: first down / next down / turnover on downs with mirrored spot, & goal, labels like "2nd & 7 at OWN 28"), `match.gd` (World + Downs; records play results from events, `next_play()` lines up at new LOS and swaps possession). **Two-way athletes** (offense/defense role + x, `World.set_offense`). AI QB throws to most-open receiver after 2.0 s or under pressure.
- Game: human always plays the same athlete (QB on offense ↔ LB on defense); auto next play 2 s after whistle (R to skip); HUD down & distance + side; blue LOS + yellow first-down turf markers.
- Tests: 60 unit (+9); game flow 21 checks. Found + fixed a flow-harness hang (setup error → empty steps → infinite error loop); flow now exits on setup failure and smoke.sh wraps Godot in `timeout`.
- Known gaps: TD/safety (A08) — spots clamp to 1..99 for now; field visuals don't mirror team colors on possession change.

## 008: A08 Scoring (2026-11-24)
- Sim: World detects touchdowns (carrier in opponent end zone, in bounds: runs + end-zone catches). Match tracks score; safety (downed/OOB at y<0, +2 defense); play-based try (1 pt from the 3 or 2 pts from the 10, `choose_try`); simplified kickoff (current defense receives at own 25). Downs clamp no longer needed for TD/safety paths.
- Game: HUD scoreboard (HOME/AWAY), TRY prompt, 1/2 keys choose try, TOUCHDOWN whistle text.
- Tests: 66 unit (+6); game flow 27 checks (forced TD → +6 → 2-pt try good → kickoff to away at 25).
- Known gaps: real kickoffs/returns logged as B09.

## 009: A09 Match flow (2026-11-24)
- Sim: `clock.gd` (2 × 5:00 halves, game clock runs only during LIVE, 20 s play clock during PRESNAP). Match: `tick()` advances clocks + auto-snaps on play-clock expiry; untimed down (play in progress at 0:00 finishes, try still played); halftime → 2nd half kickoff to the team that didn't open with the ball; FINAL with winner, `next_play()` no-op after.
- Game: HUD "H1 4:32 | PLAY 17", FINAL banner with winner; auto-advance stops at final.
- Tests: 72 unit (+6); game flow 32 checks. Flow now runs with `--fixed-fps 60` (uncapped, deterministic): ~53 s → 0.65 s.
- Known gaps: overtime logged as B10.

## 010: A10a Networking core (2026-11-24)
- A10 split into A10a (this) + A10b (prediction/interpolation).
- `src/net/protocol.gd`: compact snapshot codec (~1 packet for 14 athletes), input/action sanitizing, `apply_action()` = single authoritative entry point for human actions (reuses World/Match rule validation).
- `src/net/net_session.gd`: ENet + SceneMultiplayer `send_bytes` (`bytes_to_var` without objects). Inputs/snapshots unreliable-ordered @30 Hz; actions/welcome/events reliable. Athlete assignment: host = team 0 QB/LB, first joiner = team 1 QB/LB, then alternate; empty slots stay AI; disconnect returns athlete to pool.
- Main: `-- --host [--port] [--playclock]` / `-- --join=ADDR [--port]`; all human actions go through `do_action()`; clients render snapshots + server events; fixed athlete per person online (control switch on catch is offline-only); HUD side label uses your team; `input_override` hook for tests/bots.
- Tests: 75 unit (+3); new `scripts/net_test.sh` two-process host/client test (6 checks: welcome, team, snapshots, input authority, auto-snap + reliable events, defense snap rejected) — wired into smoke.sh, passed 3/3 runs.
- Known gaps: no prediction/interpolation yet (A10b) → client sees 30 Hz steps + RTT input lag; no NAT traversal (B07).

## 011: A10b Netcode feel (2026-11-24)
- `src/net/client_predictor.gd`: seq-tagged inputs, local stepping of own athlete, reconcile = server state + replay of unacked inputs (bounded buffer).
- `src/net/interpolator.gd`: snapshot buffer by server tick; others + ball render 100 ms in the past, lerped; clamps on underrun; drops out-of-order.
- Protocol/session: input `seq` (sanitized, never goes backwards on server), snapshots carry per-athlete `ack`.
- Tests: 80 unit (+5: prediction with simulated 6-tick latency leads then converges <0.01 yd, bounded buffer, interpolation midpoint/clamps/out-of-order, seq sanitizing). Net test now 7 checks incl. "own athlete predicted ahead of server state" — verified it fails (0 frames) with prediction disabled. 3/3 runs pass.
- Known gaps: prediction ignores collisions/blocks (server corrects on contact); no visual smoothing of corrections yet.

## 012: A11 Teams + positions (2026-11-24)
- `src/sim/roster.gd`: 7 two-way slots per team (QB/LB, WR/CB ×2, RB/S, C/DL, OL/DL, OL/S) owned by humans or bots; auto-assign balances teams + prefers QB/LB; claim/release; swap team keeps pairing; cycle position skips taken slots.
- Main builds teams from the roster; offline TAB = next position, T = swap team (only when not LIVE); HUD shows "QB/LB ... [TAB pos, T team]".
- Online: server's Roster replaces A10a's fixed pool (NetSession `assign_fn`/`release_fn`, `set_assignment` re-welcomes); clients request cycle/team/pick as reliable actions; client resets prediction on reassignment.
- Tests: 86 unit (+6); flow 38 checks (+6 incl. no swap while live); net 9 checks (+2: team-swap reassignment, occupied-slot pick rejected). Fixed a test-ordering bug (initial-team check ran after the deliberate swap).
- Known gaps: no lobby UI to see who's where (A16).

## 013: A12 Routes + play calling (2026-11-24)
- `src/sim/routes.gd`: 9 mirrored routes (GO, SLANT, OUT, IN, CURL, POST, CORNER, FLAT, WHEEL) + 6-play playbook (Verticals, Slants, Mesh, Curls, Flood, Deep Shot) by receiver order (left WR, right WR, RB).
- World: `call_play`, `set_route` (eligible receivers only), route paths computed at snap; defaults to Verticals each play. AI receivers follow paths (then continue final direction) with lane avoidance.
- Protocol: `play`/`route` actions (offense-only, presnap-only, sanitized), snapshots carry play + per-athlete routes.
- Game: Q cycles play, F cycles your own route; presnap route art for your team only (yours green); HUD shows PLAY/ROUTE.
- Tests: 91 unit (+5); flow 44 checks (+6: play call, route art shown/hidden, HUD, AI slant breaks inside).
- Known gaps: no defensive coverage schemes yet (bots A14 will add man/zone basics).

## 014: A13 Interceptions + fumbles (2026-11-24)
- Interceptions: lone defender within reach catches it (contested → breakup still). Live returns via `possession_team()`: tackles/blocks/TD direction generalized (defense scores in end zone A).
- Fumbles, deterministic: dive on a sprinting carrier from behind strips the ball; loose ball bounces/rolls with friction; nearest standing athlete recovers; loose ball OOB → dead, fumbling team keeps.
- Match: results carry carrier team → turnovers with mirrored spot, pick-six scoring + try for the defense, touchback at 25 when a takeaway is downed in own end zone.
- AI: chase loose balls; pursue whoever has the ball; returner's teammates escort/block.
- Game: INTERCEPTION/FUMBLE/RECOVERED banners; offline control follows your team's takeaway.
- Test runner now counts scripts that fail to load as failures (previously relied only on the grep in test.sh).
- Tests: 101 unit (+10); flow 47 checks (+3: forced pick, banner, possession flip).

## 015: A14 Bots (2026-11-24)
- Gaps found first: AI receiver-after-catch and AI returner stood still; no coverage; AI offense never called plays.
- Bots (`src/sim/ai.gd`): carriers run for the end zone, juke lane defenders, stay in bounds, no sprint within 4 yd of a defender (matches the fumble rule); man coverage (trail + 0.25 s reaction lag; LBs take backs, spy QB, blitz at 3.5 s; free safeties deep); ball in air → 2 nearest per side break to the landing point with arrive-steering (sprinting overshot ~2 yd), man defenders play the receiver's hands; QB drifts away from pressure, waits for 1.5 yd separation (max hold 3.2 s), leads receivers **along their route** (linear lead threw curls/outs to empty grass); presnap: situational rotating play calls, AI-only offense snaps after 2.5 s.
- Rule fixes found by bot sims: pass not catchable/deflectable for its first 2.5 yd (rushers were batting every throw at release); interceptions need the defender within 0.6 yd at the ball's closest approach (else deflection); catch-OOB event renamed `caught_out_of_bounds` (shared name crashed Match on a missing `spot`); comeback routes settle instead of backpedaling forever.
- Tools: `tools/bot_stats.gd` (all-bot game outcome stats), `tools/play_stats.gd` (per-play pass outcomes). 10-min all-bot game: 80% completion, 2 INT, 10 breakups, 41–44.
- Tests: 111 unit (+10 incl. 4-min all-bot game with balance assertions, OOB-catch regression); flow 50 checks (+3: human on defense, presnap, bot offense snaps itself).
- Known gaps: deep passing is easy vs bots (Verticals/Flood ~100%) — safety help over the top is basic; zone coverage only for unassigned safeties.

## 016: A15 Match sizes (2026-11-24)
- `src/sim/match_config.gd`: 3v3 (60×30 field, 8-yd end zones), 5v5 (80×40), 7v7 (100×53.3).
- Roster builds the first N priority slots (3v3 QB/LB + 2 WR/CB; 5v5 + RB/S + C/DL) with formation x scaled to width. No center → QB starts with the ball, snap goes straight LIVE.
- Downs/Match now goal-relative: turnover mirror, try LOS (goal−3 / goal−10), kickoff at 25% of field, OWN/OPP labels around midfield.
- Main: `-- --size=3|5|7`; `configure(size)` rebuilds field/roster/sim/views in place (containers FieldRoot/AthleteRoot); HUD shows "5v5 H1 4:32". Host's welcome carries size; clients rebuild to match.
- Tests: 118 unit (+7 incl. 3v3/5v5 all-bot games); flow 55 checks (+5: in-place 3v3 rebuild); net test now hosts 5v5 and checks the client adopts it (10 checks). Flow listeners now connect after main._ready (configure() replaces the World).

## 017: A16 Private matches (2026-11-24)
- `src/net/invite_code.gd`: IPv4+port ⇄ 10-char Crockford base32 `XXXXX-XXXXX` (forgiving O/I/L); `--join=CODE` or IP.
- `src/net/lobby.gd`: LOBBY/IN_GAME, players + ready, host-only validated settings (size 3/5/7, half 2/5/8 min; settings change clears ready), serialization. Clock half length per match.
- Host opens a lobby by default (`--no-lobby` for instant start; `--start-when-ready`, `--advertise=IP` for headless/tests); prints the invite code; lobby state broadcast reliably; clients ready via lobby actions; when all ready → configure(size) + half length + roster slots + welcomes; late joiners go straight in. Lobby HUD + keys (Enter ready; host 3/5/7, H).
- **Found + fixed a latent bug:** the real keyboard handler had never been updated since iter 002 (string-replace patches silently didn't match): Space/E/1/2 bypassed `do_action` (broken online), and TAB/T/Q/F didn't exist. Rewrote it; added real-key-event flow steps; added `tools/patch.py` (strict) + LOOP.md rules.
- Tests: 125 unit (+7); flow 61 checks (+6 real-key steps); net test joins **by invite code** through lobby ready-up (11 checks), 3/3 passes.

## 018: A17 Offline practice mode (2026-11-24)
- `src/sim/drills.gd`: Passing (you = QB, WR/WR/RB, no D, cycles playbook), Catching (you = WR vs AI QB + CB in man), Tackling (you = LB vs live AI RB, 6 s timeout), Scrimmage (7v7 bots, no clock). Drills build only their own athletes into a fresh World; reps, successes, streak/best; 1.2 s pause then auto reset. World `start_live_with(id)`.
- Main: `-- --practice=KIND`, `start_practice()`, practice never runs clocks, HUD shows drill stats; `sprint_override` hook for tests.
- **Bug found + fixed:** man coverage at the snap sent the CB "behind" an unreleased WR, i.e. through him into the backfield, shoving the receiver backwards (bots hid it by sidestepping). Defenders now hold level/inside until the receiver gets past. Bot game after fix: 10-min 70% comp, 27–41.
- Tests: 131 unit (+6 incl. regression); flow 68 checks (+7: passing drill completion via real game, rep reset, tackling drill via real E key). Route-glue flow step now runs without AI defense (inside leverage legitimately takes slants away).

## 019: A18 Casual + competitive queues (2026-11-24)
- `src/net/matchmaker.gd` (pure): casual = full teams FCFS or ≥2 after 8 s (bots fill); competitive = rating window ±(100+25/s, cap 600), full teams or ≥2 after 15 s; host = longest waiting; snake-draft teams by rating. Modes/sizes never mix.
- `src/net/mm_server.gd` (`-- --matchmaker [--port]`): queues, elects host, relays host invite code to joiners. `src/net/mm_client.gd` + main `-- --queue=casual|competitive --mm=ADDR[:PORT] [--size --rating]`: host role opens a lobby (random port, auto-ready, `expected` players), join role joins by code + auto-readies. Main refactored into `_host_game` / `_join_game` with options; "SEARCHING…" state.
- Lobby `expected`: queue matches start only when the whole group is in.
- Tests: 139 unit (+8 queue rules); new `scripts/mm_test.sh` (matchmaker + 2 queued headless clients → 3v3 match started with both humans, ~13 s) wired into smoke.sh.
- Known gap: snake-draft teams computed but not applied by the host yet → folded into A23.

## 020: A19 Chaosball (2026-11-24)
- World ruleset (`set_ruleset`): Chaosball = 0.45× gravity, anyone throws anywhere (unlimited passes), self-catch, nearest player catches (no breakups; opponent catch swings possession live), up to 3 ground/wall bounces (restitution 0.55/0.8) then incomplete, arena walls reflect the ball.
- Pass solver/lead/landing/arc preview take gravity → aim stays exact in low gravity. **Lob throws** (Ctrl on release; fixed 65° arc, speed solved to land on target) — needed because flat passes outrun a sprinter, making self-catch impossible.
- Match: Chaosball possessions are one live play; TD +6 (streak scoring A20) → kickoff; any tackle/OOB/incomplete → turnover at the spot to the team that didn't end with the ball.
- AI: pressured carriers in Chaosball pass to their most open teammate; AI aiming/landing uses world gravity.
- Mode: `-- --mode=chaosball` (forces 3v3), lobby setting (host M), welcome carries mode; HUD "CHAOSBALL 3v3".
- Tests: 151 unit (+12: low gravity, past-LOS + second pass, self-catch via lob, bounces, catch off a bounce, walls, swings, chaos turnovers, lob solver, mode setting, 2-min chaos bot game); flow +3 (mode, HUD, real lob throw past LOS).

## 021: A20 Chaosball scoring (2026-11-24)
- Pass streak: +1 per completed **teammate** catch (self-catches don't count — anti-farm), reset on interception/possession; TD value = min(2 + streak, 7).
- Pass clock: holding the ball 5 s explodes it (carrier knocked down, DEAD, Match turnover at the spot); every catch resets the clock.
- Snapshot carries streak + hold time; HUD "STREAK n -> TD v | BALL t s"; EXPLODE whistle text. AI passes when pressured **or** with < 1.2 s on the pass clock.
- Tests: 159 unit (+8); flow 73 checks (+2: streak HUD, real-game explosion).

## 022: A21 Stats (2026-11-24)
- `src/sim/stats.gd`: play-context tracking from World events; lines per **owner|POSITION** (switching positions splits your stats): passing att/comp/yds/td/int, receiving, rushing, tkl/sack/int/pbu/ff/fr, points (incl. Chaosball streak values). Yards = offense-frame gain from the snap LOS; return yards not yet tracked.
- Main: Stats per match, owner names from roster/lobby ("You", lobby names, "Bot"); at FINAL the summary prints to stdout + shows on the HUD; server broadcasts summary lines to clients.
- Tests: 165 unit (+6 incl. 3-min bot game consistency: pass yds == rec yds); flow 76 checks (+3: real completion tracked, final summary on HUD).
- Known gap: return yards after takeaways (add with B-phase stat polish).

## 023: A22 Leaderboards (2026-11-24)
- `src/sim/leaderboard.gd`: career lines per player|POSITION (games + summed stats, bots excluded), per-position scores (QB/WR/RB/C-OL/defense formulas), top-100 rankings, rank_of, JSON persistence (`user://leaderboard.json`).
- Stats gains `blk` (block engagements) so linemen rank on something real.
- Main: host/offline records the match at FINAL (not practice drills); final HUD "YOUR RANKS: QB #1, ..."; `-- --leaderboard[=POS] [--leaderboard-file=PATH]` prints the tables and exits.
- Tests: 169 unit (+4); flow 78 checks (+2: file recorded with You|QB #1, HUD rank) using a temp leaderboard file (test runs never touch the real one — verified).

## 024: A23 Ranked (2026-11-25)
- `src/sim/ranked.gd`: team Elo (K 48 provisional for 10 games, then 32; ties 0.5), tiers Bronze→Silver→Gold→Platinum→Diamond→Legend, quarterly seasons (rollover: peak-tier reward `S<id>-<TIER>`, soft reset halfway to 1000), JSON store `user://ranked.json`.
- Names: `-- --name=NAME` flows through the queue and the lobby (`name` lobby action); stats/leaderboards/ratings use them.
- Competitive: matchmaker team split now keyed by name; host seats itself + lobby players on assigned teams (`Roster.auto_assign_team`, falls back if full); ranked flag from competitive queue or `--ranked`. At FINAL the host updates/saves ratings, broadcasts deltas; HUD "RATING 1024 Silver (1-0) (+24)". Queue sends your stored rating.
- Tests: 176 unit (+7); flow 80 checks (+2: ranked final saves ratings + HUD delta, temp files only); `MODE=competitive mm_test.sh` verifies named players seated by snake draft (Ben 1050 → team 0, Ann 1000 → team 1) and ranked=true — both casual and competitive runs in smoke.sh.

## 025: A24 Cosmetics (2026-11-25)
- `src/sim/cosmetics.gd`: catalog (trim colors, helmet stripes, numbers 0–99, TD celebrations spin/hop/flip, season badges), level unlocks (500 XP/level), XP award from your stats + win, equip validation, server-side `sanitize_look`, JSON profile.
- Views: trim band, helmet + stripe, front/back number labels, celebration animation on your TD. Looks never enter the sim (test: identical worlds regardless of looks).
- Sync: client sends its look after assignment; host sanitizes, stores per peer, broadcasts `looks` (on join, swaps, changes); client shows its look only via the host echo. At FINAL host broadcasts `awards`; each machine credits only its own profile ("XP +182 (Level 1)"); ranked season rewards become badges. CLI `--equip=slot:id,...`, `--profile-file`.
- **Data-safety fix:** the first smoke run wrote a test XP profile into the real user-data folder (created by this session; deleted). All tests now use temp profile/leaderboard/ranked files and smoke.sh fails if real user data files change.
- Tests: 182 unit (+6); flow 87 checks (+7); net 12 checks (+1: #88 round-trips via host).

## 026: A25 Replays (2026-11-25)
- `src/sim/replay.gd`: 30 Hz compact frames (phase, ball xyz, per-athlete x/y/flags), plays bracketed snap → play-end events, player (fractional time, speed, interpolation, seek by play, clip ranges), zstd-compressed save/load (no object decoding). 2-min bot match: 3600 frames, 20 plays, ~170 KB.
- Main: every match records; **V** at a dead ball = instant replay of the last play at 0.5× (offline the match pauses; host keeps simulating; views read replay frames — no player.gd change); final saves `user://replays/<timestamp>.replay` (`--replay-dir`); `-- --replay=FILE` viewer (Space, ←/→ plays, [ ] speed, V exit); replay HUD line.
- Coordination: a parallel session owns A26 graphics (branch graphics-overhaul); FEATURES marks A26 `[~]` so the loop skips it; scorebug part of A27 deferred to their overlay; player.gd/_build_field/_draw_routes/_marker left untouched.
- Tests: 186 unit (+4); flow 97 checks (+11: real V key, frames shown, sim frozen, replay ends, saved at final, viewer + speed key + exit).

## 027: A28 pre-audit (2026-11-25)
- `docs/PARITY.md`: every Gridiron feature (G01–G26) → where it's built → machine-checkable evidence lines (unit PASS / flow OK / net OK / mm PASS). `scripts/parity_audit.sh` runs all suites and verifies evidence; exit 0 only with 0 fail, 0 gaps, 0 pending (`SKIP_RUN=1` re-checks last logs). Verified it discriminates (planted fake evidence → FAIL).
- Result: 21 PASS, 3 GAP → filed D02 party queue (G09), D03 Chaosball in matchmaking (G17), D04 achievements (G23); +D05 return yards (A21 gap). 2 PENDING in parallel sessions: G25 controls/menus/settings (A27), G26 stadium presentation (A26).
- A28 stays unchecked until the gaps are closed and A26/A27 merge; then the audit must pass.

## 028: D02 Party queue (2026-11-25)
- Matchmaker units (solo or complete party), party-aware FCFS/rating-window forming, `unit_teams` split keeps parties together; `--party=CODE:SIZE` through client/server/main. Parity G09 now automated.
- Process: iter 027's `git add -A` swept another session's uncommitted files (AGENTS.md, CLAUDE.md, docs/TESTING.md, shot.sh, capture.gd) into my commit — content is theirs and intact; LOOP.md now requires explicit-path staging.
- Tests: 190 unit (+4); `MODE=party mm_test.sh` (Ann+Ben seated together) added to smoke.sh and the parity audit.

## 029: D03 Chaosball in matchmaking (2026-11-25)
- Matchmaker `game` dimension (classic/chaosball, Chaosball forced 3v3) through server/client/main; host lobby opens in the queued game mode. Parity G17 automated.
- Tests: 191 unit (+1); `MODE=chaos mm_test.sh` in smoke.sh + parity audit.

## 030: D04 Achievements (2026-11-25)
- `src/sim/achievements.gd`: 12 original milestones (First Touchdown, First Win, Gunslinger, Sure Hands, Workhorse, Sack Artist, Lockdown, Pick Six, Perfect Chaos, Comeback Kids, Going for Gold, Iron Man) as predicates over a per-player match context; bonus XP each. Stats `def_td` + `max_td_pts`; Match `max_deficit`; profile `achievements` + `games`.
- FINAL: host computes ranked first, then per-human contexts, broadcasts `awards` {xp, ctx}; each machine evaluates/saves only its own player; HUD "ACHIEVEMENTS: …". Parity G23 automated → all 3 pre-audit gaps closed.
- Found: flow steps placed out of frame order silently never ran (harness quits after the last listed step) → game_flow.gd now sorts steps by frame.
- Tests: 196 unit (+5); flow +3 (real TD + win unlocks + HUD + saved).

## 031: A28 Parity audit — PASS (2026-11-25)
- Pulled and verified the parallel merges on main: out-of-game (A27 menus/settings/rebinding/gamepad, B07 UPnP/public matchmaker, Crater Bowl identity, exports) and graphics (A26 rigged CC0 characters, stadium, overlay/scorebug, presentation). Combined tree: 205 unit, game/menu/net flows, 4 matchmaking scenarios, user data untouched.
- Data-safety fixes while merging: flow test now isolates replays from frame 2 (earlier finals had written test replays into the real replays/ folder in both old and new user dirs — 36 test-only files, deleted); smoke guard now covers replays/ and cleans test_flow_replays. Real settings.cfg was not written by our tests (left untouched).
- Parity: G25 evidence = menu_flow (name, matchmaking, rebinding via real keys, gamepad, Esc overlay) + unit tests; G26 evidence = offscreen real-renderer screenshots (viewed: stadium, rigged players, scorebug, live play).
- `./scripts/parity_audit.sh` full run: **26/26 PASS, 0 gaps, 0 pending** (7m11s). Built game: `./scripts/export.sh Linux` → CraterBowl-0.1.0-linux.zip, EXPORT BOOT CHECK PASS.
- Phase A complete. Open follow-ups: D05 return yards; Phase B items (B07 owned by out-of-game session); Phase C TODOs from docs/gaps.

## 030: C08a Defensive playbook (2026-11-25)
- Added nine named defensive calls across man, zone and blitz families and base, goal-line and prevent shells. Suggestions use down, yards to gain, yards to goal and time remaining.
- C08b still owns on-field assignments and play art. B03 still owns the huddle.
- Tests: 202 unit (+2); full smoke passed with isolated user data after the shared settings file changed during the baseline run.

## 031: C08b Defensive play selection and synchronization (2026-11-25)
- Classic matches seed a defensive call from the game situation each snap. The host accepts catalog calls from defending athletes during presnap and sends the current call in match snapshots.
- Player controls, assignment behavior and play art remain open in C08c and B03.
- Tests: 204 unit (+2); full smoke passed, including a remote defender's selection round-tripping through the host.

## 032: C08c + B03 Defensive assignments and play-call huddle (2026-11-25)
- Classic presnap shows a five-second play-call panel for both teams. Q cycles calls, L recalls the team's last call, X mirrors the offense's wide receiver routes, and Y opts into the situational default without the panel.
- Calls drive bot man, zone and rush behavior. Presnap turf art shows teammates' coverage landmarks, man tethers, rush lanes, receiver routes and pass protection targets. The local assignment is emphasized.
- Cover 2 allowed 1 deep completion across 24 matched bot snaps versus 8 with legacy coverage. Deep attempts fell from 10 to 1.
- Tests: 208 unit (+4) and full smoke passed, including remote recall. Checked offense and defense screenshots offscreen. An initial smoke attempt hit a matchmaker port bind error and passed on retry.

## 033: C01 Run game (2026-11-25)
- Added Inside Zone and Outside Sweep for classic 5v5 and 7v7. The huddle and turf show the RB path and linemen's targets. X mirrors the run.
- The QB uses G or gamepad R3 to hand off to an adjacent RB behind the line. The host validates the exchange and its cooldown. Offline control follows the RB. Online players keep their assigned slots.
- Bots mix runs with passes and block for the chosen lane. The RB gets the carry and yards at the whistle or fumble spot. The two-minute bot match finished 0–2 with 12 handoffs and 33 throws.
- Verified 238 unit tests and full headless smoke, including a remote QB handoff. Viewed offscreen captures of the sweep, the exchange prompt and the controlled RB. The smoke guard now checks the active XDG data directory so other checkouts' replay files cannot invalidate an isolated run.

## 034: C04a Running clock and team timeouts (2026-11-25)
- The game clock runs between plays after a short in-bounds tackle. First downs, possession changes, sideline stops, incompletions and scores stop the clock. Tries are untimed.
- Each half has a one-minute warning. A live play can finish before the warning. A half can also end between snaps.
- U spends a team timeout between plays. The scorebug shows three per team, or two in 3v3. The host validates the caller, and halftime restores the counts.
- Verified 245 unit tests and full headless smoke, including a remote timeout. Viewed offscreen captures of the timeout banner and visible pips before and after the snap. Quarters and the mercy rule remain in C04b.

## 035: B09 + C02 Kicking game (2026-11-25, #2, #3)
- Coin toss (`Match.start_match`): deterministic from a seed (`--toss=N`), winner has 5 s to press 1 receive / 2 kick (bots and no answer = receive), other team receives the 2nd half.
- Live kickoffs from the 35 (20 after a safety): kicker on the tee, coverage spread, front row + two deep returners. Space/play clock = default kick; J/LMB = aimed kick with the throw meter (arc preview shows the kick). Returns, touchbacks (25), out of bounds (40), rolled/downed spots. Onside recovery exists as an opt-in mutator (`world.onside`, off by default per the gap notes; C27 owns turning it on).
- K cycles the kick call on any scrimmage down: punt (punter 10 deep, returner drops back; touchback 20, return/downed spots, fake punts play normal downs) or field goal (holder 7 deep; good = between the uprights above the 3.3 yd crossbar at the end line; miss = defense at the kick spot or its 20). 1-pt try = PAT kick from the 15; 2-pt stays scrimmage from the 10.
- Blocks: a rusher within 1 yd of the ball in its first 5 yd blocks it; the ball pops up live (scoop and score; kicking-team recovery plays downs).
- Bots: 4th-down rule (FG within 50 yd, go on 4th & ≤2 past midfield, else punt), kick PATs, vary kickoff depth; coverage lanes, a returner under the ball, a return wall.
- Net: `kick`/`kick_call`/`toss` actions sanitized + routed; snapshots carry the kick call, kicked flag and toss winner. Huddle skipped on kickoffs; play card shows kick instructions.
- Merged with iter 032 (Codex huddle): kicks go live through `_go_live()` so stance locks release.
- Test changes: the scoring/clock/size tests now expect live kickoffs and the PAT from the 15; game_flow opens on the toss then resets to a scrimmage for the legacy steps (`opening_kickoff`); net_test host runs `--no-kickoff` (its defense/offense checks assume a scrimmage opener).
- Tests: 260 unit after the merge (30 new in test_kicking.gd incl. a full bot match with kicks); flow adds toss (2 key), metered kickoff + arc + return, K punt, K K field goal +3. Screenshots checked: toss prompt, kickoff coverage, return.
- Follow-ups filed: kicking stats, stepped meter/tee art, fair catch + bot 2-pt (filed as D06–D08, migrated to issues #67–#69).

## Process: backlog → GitHub issues (2026-11-25, #1)
- Not a game iteration (no number). The backlog moved from `FEATURES.md` / `docs/gaps/TODO.md` checklists to GitHub issues #2–#51, with labels for type, priority, area and status. Old ids map via `docs/backlog/legacy-ids.md`. Team voice chat was planned as #31.
- Docs split into feature level (`docs/features/`) and design level (`docs/design/`). `PLAN.md` → `docs/vision.md`, `docs/gaps/` → `docs/research/`, plus a new `docs/workflow.md`. `LOOP.md` now picks from issues, and the daily gap review files and updates issues.
- From here on, every iteration entry cites its issue, and every "known gap" is an issue number.

## 036: B04a Play replays (2026-11-25, #36)
- `replay.gd`: per-play summaries from sim events (yards from LOS, pass/run, TOUCHDOWN / INTERCEPTION / FUMBLE LOST / SACK tags, 20+ yd = highlight, clock + down context in the label). Highlight clips run at 1x and finish with a 2 s slow-mo. Also adds a highlight reel, next-highlight, frame-step and progress. Files from before this change still load; the save version is now 2.
- Main: offline highlights auto-replay 1 s after the whistle (once; V/Enter skips; `--auto-replay=0`). In-match and viewer transport: Space, `,` `.`, ←/→, H, `[ ]`, C. Ball-tracking replay cameras (Broadcast / End zone / Sky / Player) cut in, then track. V at FINAL plays the highlight reel.
- `src/game/replay_overlay.gd`: broadcast REPLAY / HIGHLIGHT / REEL bug, summary, context, progress bar, hints. It hides the live overlay widgets during the replay and restores them; `overlay.gd` (A26) is untouched.
- Tests: 208 unit (+4); flow 116 checks (+19, real keys). Verified visually with shot.sh: sack highlight on the Broadcast cam, then on the End zone cam in slow-mo.
- Merging origin/main: the final whistle now ends an auto highlight (the summary and postgame take over; the reel still has it), and the postgame waits while a replay plays. The replay overlay looks up match-overlay widgets by name (the controls rework removed `card` and `hints`). origin/main itself fails `lint` (player.gd shield_mesh, world.gd `_impact_rng`, from ec09b1e) and the perf render budget (shadow_casters 125/110 from the team models); both are identical with or without this branch. Landed after the kicking merge: game_flow turns auto replay off by default (scripted timings assume the offline sim never pauses) and on only for the B04a steps. Unit 305 and smoke (flow 187) pass.
- Remaining scope stays on #36: online auto replay needs a skip vote (MVP card is covered by the Players of the Game postgame); free-cam theater; clip export; no Settings toggle for auto replay yet (CLI flag only). An `mm_test` competitive run failed once under load from 14 Godot processes run by other sessions; it passed 3/3 alone.

## 037: Compact scorebug (2026-11-25)

- [#13](https://github.com/bpenwell/CraterBowl/issues/13) groups the mode, ball spot and mini field with the existing score, possession, clocks, timeouts and down state.
- The rendered integration test checks these details and captures scrimmage, kickoff and conversion states.

## 038: C04b Four-quarter format (2026-11-25, #4)

- Private hosts press Q to switch between halves and quarters, and H to select the duration. Halves remain the default. The lobby and snapshots carry the selected format and the scorebug displays the current period.
- Q1 and Q3 preserve the drive and timeouts. A live play and its try can finish at 0:00. Q2 ends with the halftime kickoff and timeout reset, and Q4 ends the match. The one-minute warning still occurs once per half.
- Verified 311 unit tests, 191 gameplay checks, 57 menu checks and 21 network checks. Viewed offscreen captures of the host controls and quarter scorebug. The quarter-transition regression failed when the quarter counter was held at Q1.
- Updated the rules guide for the coin toss, PAT and fumble roll (#73). Follow-ups #74 and #75 cover the menu's Chaosball selection and the stadium clock during the lobby.

## Fix: Host lobby UPnP notice (#47)
- The host lobby shows the router mapping failure and the UDP port to forward. The invite code still uses the LAN address when mapping fails.
- The menu flow test simulates a router failure and checks the warning in a real host lobby on a custom port.

## 039: Roster rejection tests (2026-11-25, #52)

- Added direct tests for rejecting legacy team and slot requests at the match protocol and for preserving both players' assignments when a roster slot is occupied.
- The network flow still sends both requests and checks that the client keeps its host-assigned athlete and team.
- Verified 312 unit tests and 21 network checks. Deliberately allowing the legacy requests or bypassing the occupied-slot guard caused the corresponding unit checks to fail.
- Documented the match assignment policy and the three kicking actions in the protocol guide (#76). Pre-match role selection remains tracked in #18.

## Fix: Validate match action types on the host (#77)
- The host now drops `act` messages that aren't a Dictionary with a String `a` before they reach its action queue (`Protocol.is_action`). `apply_action` takes an untyped action and rejects junk instead of aborting the caller. `lob`/`spr`/`block` flags are type-checked rather than compared with `== true`.
- Before the fix, one malformed action raised a script error in `_step_authoritative`. That aborted the host tick and dropped any valid action queued behind it in the same tick.
- Verified with 4 new unit tests (`test_action_validation.gd`) and a rendered host test (`tests/visual/invalid_actions_test.gd`). Restoring the old `protocol.gd`/`net_session.gd` made both fail: the unit queue test because 16 entries were queued instead of 1, and the visual test because of a script error and a dropped play call. Design notes are in `docs/design/netcode.md` under Validation.

## Fix: Explicit human flag on sim inputs (#62)
- `world.step` used to treat an input as human iff it had a `"block"` key, so a bot input that ever carried `block` would silently switch to human blocking rules (no auto-engage, release on letting go of the shield). Inputs now carry an explicit `World.HUMAN` flag (`World.is_human_input`). `main.gd` sets it on the local player's input and, on the host, on every peer's sanitized input; the wire never carries it. Player-facing behavior is unchanged.
- Verified with 4 new unit tests in `test_blocking.gd` (human input without a `block` key doesn't auto-engage and releases a block; a bot input with `block: false` still auto-engages and isn't released) and a rendered host test (`tests/visual/peer_human_block_test.gd`). Restoring the old `has("block")` rule failed 3 of the unit tests; dropping the host-side flag in `main.gd` failed the visual test (the peer lineman auto-engaged). Determinism tests unchanged (all-bot games).

## Fix: Chaosball locks the menu Size picker (#83)
- On the Online and VS Bots screens, picking Chaosball now shows the Size row as a dimmed, disabled 3v3 (Chaosball is always 3v3). `pick_size` is left untouched, so switching back to Classic re-highlights the earlier 3v3/5v5/7v7 pick. Before, the row stayed live with 5v5/7v7 highlighted, implying a 7v7 Chaosball match.
- The theme's disabled box hides the pressed state, so the locked 3v3 gets a dimmed cyan override to still read as the pick.
- `tests/menu_flow.gd` (step 1000) presses the real Rules buttons on both screens and checks the row state; it failed on origin/main's menu (`7/enabled` instead of `3/disabled`). `tests/visual/size_picker_chaosball_test.gd` captures both states.
- Side findings: #92 (headless menu_flow logs ~400 dummy-renderer mesh errors), #94 (chaosball.md pointed at the wrong label; fixed here).
