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
