# Gap TODOs (Phase C)

Ordered by priority, so take items top to bottom. Each item is scoped, not designed; the real design pass happens in `docs/iterations/NNN-*.md` when the loop picks it up. Acceptance criteria are written so they can become tests (`tests/test_*.gd`, `game_flow.gd`, `net_client.gd`). If an item is too big for one iteration, split it here (C01a, C01b) and do the first half.

Source tags: O = original Gridiron, R = Gridiron Remastered, Gx = genre game, PLAN = our PLAN.md. See `GAP_ANALYSIS.md` for the matrix and `reviews/` for URLs.

---

## P0: core football a player notices in match one

### [ ] C01 Run game: handoffs, run plays, RB carries
- **Why:** Gridiron had animated handoffs with a re-handoff cooldown and 2 s of stamina immunity (O 1.0.3.52/53). Ours is pass-only, so RBs and OL have nothing to do on most plays. This is the single biggest feel gap.
- **Accept:**
  - QB can hand the ball to an adjacent back with an action key. Possession transfers in the sim, and a second handoff is blocked by a cooldown.
  - The playbook gains at least 2 run plays (inside zone, outside sweep) with blocking assignments. Bot RBs follow the run path, and bot OL block for it.
  - A run past the line keeps the play live. Stats credit rushing attempts and yards to the RB.
  - Bots call run plays some fraction of the time, and the 2-min bot game still finishes with a sane score.
- **Touch:** `world.gd` (possession transfer), `routes.gd` (plays), `ai.gd`, `stats.gd`, `protocol.gd` (whitelist `handoff`).

### [ ] C02 Kicking game: coin toss, punts, field goals, PAT kicks
- **Why:** Gridiron had a coin toss, punts with a power meter, punt returns, FGs, PATs, FG blocks, and scoop-and-score on blocked kicks. A missed FG gives the ball to the defense at the kick spot, or at the 20 when the kick was inside it (O 1.0.4.31). We have none of these, so 4th down is always go-for-it. **Kickoffs + returns are B09**; build B09 first or together with this, sharing the kick meter.
- **Accept:**
  - The match starts with a coin toss whose winner chooses to kick or receive.
  - On 4th down the offense can punt. The kick uses an aim + power meter, the ball is live on the return, and touchbacks and out-of-bounds are spotted correctly.
  - FG/PAT: success is decided by flight through the uprights. A miss gives the defense the ball at the spot, or the 20. Defenders can block a kick, and a blocked kick is a live ball.
  - The try choice becomes kick (1 pt) / scrimmage (2 pt).
  - Bots punt or kick on 4th down using a simple field-position rule.
- **Touch:** new `src/sim/kicking.gd`, `match.gd` (`_kickoff`, try), `downs.gd`, `ai.gd`.

### [ ] C03 Movement moveset: jump, dive, dash, spin, stiff-arm
- **Why:** Gridiron's skill expression came from jump, dive (no stamina cost, 10% shorter for carriers), a side dash that costs stamina, and a DL spin (O 2021 patches). Genre games add the juke and stiff-arm. Ours has only a tackle dive and a bot-only sidestep. Pillar 3: "deep to master."
- **Accept:**
  - Jump, with stamina drain on chained jumps.
  - Ball-carrier dive for extra yards, which ends the play at the landing spot.
  - Dash in a direction, costing stamina, with a cooldown.
  - Stiff-arm: within a timing window it breaks one tackle attempt and has a cooldown.
  - Spin: a short dodge with a rotating hitbox.
  - All moves are deterministic in the sim, predicted on the client (C30), and stay at four or so buttons, keeping to pillar 3.
- **Addendum (Chaosball):** double jump, dash-down, and a dive-cancel (O 1.0.4.12).
- **Guardrail:** Gridiron's "everyone jump-spams for the Hail Mary" meta. Jump catches need a stamina cost and a contested-catch rule (C07).

### [ ] C04 Clock management: timeouts, one-minute warning, running clock, quarter length
- **Why:** Gridiron has timeouts on a key, a one-minute warning, a mercy rule and configurable quarter length (O 1.0.3.18/20). Our clock stops between every play, so clock management doesn't exist, and late-game drama, one of pillar 1's stories, is missing.
- **Accept:**
  - The clock keeps running between plays after an in-bounds tackle and stops on an incompletion, out of bounds, a score or a change of possession.
  - Each team gets 3 timeouts per half (2 in 3v3), callable by any player on the team in a dead-ball phase.
  - Under 1:00 in each half there is an automatic stoppage, and the clock stops after first downs.
  - Mercy rule: the game ends when one team leads by 28 or more (host option).
  - Quarter length is a lobby setting.
  - Spike and kneel actions (stretch).
- **Touch:** `clock.gd`, `match.gd`, `lobby.gd` settings, HUD.

### [ ] C05 Competitive rules: eligibility, grounding, blocking zone, QB slowdown
- **Why:** Gridiron's competitive ruleset (O 1.0.3.18/29, 1.0.4.29/47) targets exactly the "Hail Mary simulator" complaint. Its rules: blockers can't go more than 5 yd downfield until a pass or run, linemen with the shield up are ineligible, grounding is a penalty, and the QB slows progressively from 14 yd behind the LOS to a floor at 20 yd.
- **Accept:**
  - QB speed scales down between 14 and 20 yd behind the LOS (tuning constants).
  - A blocker past +5 yd before the throw draws a flag (penalty: 10 yd, replay the down). The bot OL respects the zone.
  - Intentional grounding: a throw with no eligible receiver within N yd while under pressure costs loss of down plus the spot.
  - A minimal penalty pipeline (flag → enforce → HUD text) that later rules reuse.
  - **Decision for the user/designer:** offsides/false start stay *impossible by construction* (current clamp) or become penalties. Default: keep them impossible; arcade feel.
- **Touch:** new `src/sim/penalties.gd`, `world.gd`, `player_motion.gd`, `ai.gd`.

### [ ] C06 Spotting: forward progress, return yards, fumble variety
- **Why:** The ball is spotted where the carrier is at the whistle, with no forward-progress rule (a carrier driven backward loses yards). Fumbles happen only from a dive from behind on a sprinting carrier. Return yards aren't tracked (iter 022 gap).
- **Accept:**
  - The spot is the carrier's max forward progress during the contact window.
  - Fumble chance scales with hit speed or a tackle from behind, and is still deterministic given a seed.
  - INT and fumble return yards land in stats.

### [ ] C07 Catch rules: toe-taps, batted balls, catch button, dive/jump catches
- **Why:** Gridiron counts the catch where the feet land (O 1.0.3.18), and a defender touching the ball within 5 yd of the throw makes it incomplete rather than an INT (O 1.0.3.35). Our catch is automatic, every contested ball is a breakup, and any out-of-bounds catch is incomplete.
- **Accept:**
  - A sideline catch is complete when the catcher's foot position at the catch is in bounds.
  - A defender tipping the ball within 5 yd of the throw point makes it incomplete with no INT.
  - An optional "catch" input gives a larger catch window with timing. The automatic catch remains the fallback, and the host can toggle it (assist mode, C19).
  - Contested catches resolve by position plus timing instead of always a breakup.
  - Dive and jump catch animations reuse the C03 moves.

### [ ] C08 Defense: play calls, zone coverage, blitzes, play art for everyone
- **Why:** Gridiron draws every player's assignment on the field: routes, blocks, man or zone, and blitz lane (O 1.0.4.47). Defense has pre-snap free roam (except DL). We have man coverage only, no defensive calls, and play art only for offense. That violates pillar 2 ("everyone matters").
- **Accept:**
  - The defense picks from 4 or more calls: Cover 1 man, Cover 2 zone, Cover 3 zone, and a blitz.
  - Zone defenders hold landmarks and break on the throw.
  - Pre-snap, non-DL defenders can move freely on their side of the line.
  - Every human sees their own assignment drawn: route, block target, zone area or blitz lane.
  - Bots play each call correctly. A bot sim shows deep completion rate drops versus the current baseline, addressing the "deep passes too easy vs bots" note.
- **Overlaps:** B03 (play-card huddle) supplies the card UI. This item supplies the defensive content.

### [ ] C09 Offense depth: formations, audibles, hot routes, pre-snap motion
- **Why:** Gridiron's QB or captain picks formations and plays and can audible (O). The genre's social hook is "QB re-routes a friend live" (Gx Madden, Retro Bowl). We have 6 pass plays from one formation.
- **Accept:**
  - Two or more formations per match size, e.g. shotgun and trips.
  - The QB can audible to another play pre-snap. A receiver gets a hot route from the QB, and the QB sees the human receiver's chosen route.
  - Motion: one receiver can be sent in motion pre-snap.
  - Play art updates live for all teammates.

### [ ] C10 Throw readability: landing marker, aim-zoom
- **Why:** Gridiron shows where the ball will land and has a toggleable ball indicator plus aim-zoom on right click (O 2020-08, 1.0.3.32, 1.0.4.24). It's cheap and helps new players a lot.
- **Accept:**
  - While aiming, a landing reticle is drawn from the same ballistic solver as the sim, so the reticle matches the landing spot within 0.5 yd in a test.
  - While the ball is in flight, eligible players see the landing spot (host toggle).
  - Holding aim narrows the camera FOV.

---

## P1: online, social, trust, onboarding

### [ ] C11 Reconnect, leavers, forfeit
- **Why:** In a 3v3, one dropped player ruins the match. Gridiron had reconnect plus leave/dodge penalties. Rocket League re-invites a dropped player, escalates queue bans for quitting, and offers a unanimous forfeit vote. Ours: a dropped peer's athlete goes to a bot, and rejoining counts as a new player.
- **Accept:**
  - A player who drops and rejoins within 120 s with the same name/token gets their slot, position, look and stats line back.
  - The bot holds the slot meanwhile.
  - A forfeit vote (unanimous, after the half) ends the game as a loss.
  - Ranked: quitting before FINAL counts as a loss, and the matchmaker applies a short queue cooldown.
  - Covered by `net_test.sh` (kill client → restart → same slot).

### [ ] C12 Position assignment: QB vote, role preferences
- **Why:** Gridiron had QB voting that showed each candidate's QBR, one re-vote at half-time and a mutual position swap. Its role queue spent role points on popular roles, earned by playing line, and unlocked after 25 games (O 1.0.4.x). Ours is first-come TAB cycling, which in public matches means everyone fights for QB.
- **Accept:**
  - The lobby shows a role preference per player.
  - In public matches, QB is chosen by a vote that shows each candidate's QBR (from leaderboard data), with one re-vote at half-time.
  - Two players can swap positions if both confirm.
  - Private lobbies keep free choice.

### [ ] C13 Communication: quick-chat wheel, pings, text chat
- **Why:** Gridiron had text chat (global/party/team), mute, and a per-position quick-comm wheel (O 1.0.4.47). Rocket League keeps adding quick-chat categories. Most coordination works without voice, and friend groups use Discord for voice.
- **Accept:**
  - The quick-chat wheel has position-specific lines: QB "Hot route!", WR "I'm open", D "Blitz!", "Nice catch!". Lines are rate-limited.
  - A world ping marks a spot or player.
  - Text chat with team/all channels, a host mute and a local mute.
  - All messages flow host-authoritatively and are tested over `net_test`.
  - Voice is **out of scope** (note in iteration doc).

### [ ] C14 Spectators
- **Why:** Gridiron allowed up to 4 spectators who could cycle players, jump to the QB, and see the feed and scoreboard (O 1.0.3.37). It's useful for friends waiting a turn, and later for casting.
- **Accept:**
  - Private lobbies accept spectator joins up to 4. Spectators take no roster slot.
  - The spectator camera cycles players and has a QB hotkey and a broadcast-wide view.
  - Spectators receive snapshots but their inputs are rejected server-side (test).

### [ ] C15 Find a game without port-forwarding: dedicated server + browser
- **Why:** The invite code is a raw IP:port. Gridiron ran on hosted servers with a public lobby browser (O 1.0.5.1). B07 (UPnP/public matchmaker) is owned by the out-of-game session. This item is the remainder.
- **Accept:**
  - A `--dedicated` headless mode where the host is not a player and the authority runs at 30 Hz.
  - The matchmaker lists public custom lobbies (name, mode, size, players, ping) and a client can join from the list.
  - Coordinate with B07 before starting.

### [ ] C16 Audio foundation + live play feed
- **Why:** There is no AudioStream anywhere. Gridiron had a reacting crowd, a whistle, and distinct INT and broken-block stingers (O 2020-10). B06 adds "juice" on top, but there's no base to build on.
- **Accept:**
  - An audio bus layout (Master/SFX/Crowd/UI) connected to A27's volume settings.
  - Event-driven SFX for: snap, throw, catch, incompletion, tackle, big hit, whistle, TD, INT, fumble, explosion (Chaosball).
  - A crowd bed that swells on big plays.
  - CC0 sources only, logged in `ASSETS.md`.
  - The HUD play feed shows each play's result in plain words ("Ann 12-yd pass to Ben").
  - Headless tests assert the right events fire, using a dummy driver.

### [ ] C17 1v1 Catching mode
- **Why:** Gridiron's 1v1 Catching mode was a race to 15 catches from a robot QB (O 2021-04-28). It's tiny to build with the existing drills and bots, and it's a fun warm-up while a lobby fills.
- **Accept:**
  - The mode puts two humans (or a human and a bot) on a scaled field. A bot QB throws contested balls, and the first to 15 catches wins.
  - Selectable in practice and in private lobbies.

### [ ] C18 Guided tutorial
- **Why:** Gridiron shipped a tutorial (O 1.0.3.37). PLAN's Phase 3 exit test is "an outside friend can learn it in one game." Drills exist but nothing teaches the controls step by step.
- **Accept:**
  - A first-launch tutorial with five steps: move/sprint → catch → throw → tackle → block. Each step waits for the player to succeed and uses the real input actions.
  - It can be skipped, and it reruns from the menu (after A27).
  - `game_flow` drives it end to end with real keys.

### [ ] C19 Accessibility & camera options
- **Why:** Gridiron had colorblind team outlines, FOV, effect reduction, streamer mode and a UI hue shifter (O 1.0.3.42), plus look-behind, free-look, ball cam and a QB first/third-person option. Assist options are retention features in mixed-skill friend groups (PLAN assumption 3).
- **Accept:**
  - Team outline colors are configurable, with presets for deuteranopia, protanopia and tritanopia.
  - FOV slider.
  - Screenshake/hit-stop reduction toggle (for B06).
  - Look-behind hold key and ball-cam toggle.
  - Assist mode (auto-catch, aim assist) is per player, host-allowed, and shown on the HUD.
  - Builds on A27 settings; don't start until A27 merges.

### [ ] C20 Rematch and keep-the-lobby
- **Why:** Gridiron had no rematch flow. Genre research's #1 retention lever for friend groups is "same lobby, go again" with near-zero friction (Gx Rocket League, Rematch).
- **Accept:**
  - At FINAL every player can vote Rematch (same teams) or Shuffle (re-draft by rating). A majority starts a new match in the same session within 10 s.
  - Cosmetics, names and ready states persist across the rematch.

### [ ] C21 Host tools: mutators, ref console, kick/mute
- **Why:** Gridiron custom matches had a ref console (O 1.0.3.9), reports, mutes and kicks. Genre: a mutator panel makes private lobbies a toy box (Gx Rocket League; our Chaosball knobs are already constants). B08 makes tuning data-driven, and this item exposes a safe subset per lobby.
- **Accept:**
  - The lobby has settings for: gravity, quarter length, score values, pass-clock length, bounce cap, mercy rule, and kicking on/off.
  - Settings sync to clients and are recorded in the replay header.
  - Host commands: kick, mute, pause, spot ball, reset down.
  - Ranked lobbies ignore mutators (test).

### [ ] C22 Trustworthy progression
- **Why:** Ratings and leaderboards live in the host's JSON, and XP is credited by each client to itself. Anyone can edit a file or run a modded host. This is fine among friends and broken for public ranked.
- **Accept:**
  - The matchmaker (or a small results service) becomes the record of truth for ranked results.
  - The host submits a signed result plus a replay hash, and the service recomputes Elo.
  - Clients display server values.
  - Local/offline play keeps local files.
  - Scope note: a full account system is out of scope. A per-install key pair is enough for v1.

### [ ] C23 New-player protection
- **Why:** Gridiron complaint #5: new players faced 500-hour veterans. Gx Rematch gates ranked behind quick-match level 5 and runs 5 placement games.
- **Accept:**
  - Ranked unlocks at level 5 (or N casual games).
  - 5 placement games with a widened K.
  - The casual matchmaker weights games played as well as rating.
  - The HUD shows "placement 3/5".

### [ ] C24 Match history and profile
- **Why:** Gridiron had a 50-match history, profile stats, QBR and per-position casual/ranked views. Ours: career lines live inside the leaderboard file, and there is no history or QBR. Achievements are D04.
- **Accept:**
  - The last 50 matches are stored with: mode, size, score, your position line, rating delta, and a replay path.
  - The profile view shows per-position career stats and QBR (formula documented).
  - CLI `--history` prints them.

---

## P2: better than Gridiron, and polish

### [ ] C25 Momentum / "on fire"
- **Why:** NBA Jam / Blitz "on fire" creates comeback swings and stories (Gx). This is pillar 1.
- **Accept:**
  - Three straight successes (completions, stops) give the team a visible momentum state with a small tuned buff, e.g. +3% speed or a bigger catch radius.
  - The state ends on a failure or a turnover.
  - Host toggle, off in ranked by default.
  - A bot sim confirms win rate doesn't skew more than X%.

### [ ] C26 Archetypes (one passive each)
- **Why:** Archetypes give players a role identity (Gx Madden The Yard, CFB25). Keep it to one passive so it doesn't become pay-to-win, and it is never purchasable.
- **Accept:**
  - 4 archetypes: Arm (+throw speed), Burner (+top speed, −stamina), Tank (stiff-arm wins more often), Ballhawk (bigger INT radius).
  - Each is chosen per position in the lobby.
  - All are plain sim tuning, and a bot sim shows no archetype is dominant.

### [ ] C27 Backyard rules / trick plays
- **Why:** At 3v3–7v7, rule novelty matters more than playbook depth (Gx The Yard: multiple passes, snap to anyone, trick plays; MFL dirty tricks). The original Gridiron removed onside kicks; we can keep them as a toggle.
- **Accept:**
  - Mutators (C21) for: laterals/backward passes anywhere, snap to any player, onside kick any time, and once-per-half trick cards (e.g. flea flicker, fake punt).
  - Each mutator is a sim rule with a test.

### [ ] C28 Commentary barks
- **Why:** A punny announcer is cheap and sells the arcade feel (Gx MFL, Blitz).
- **Accept:**
  - 30 or more short lines are triggered by play-feed events (C16), with a cooldown and no repeats within 5 minutes.
  - Original lines, recorded by friends or CC0 TTS.
  - A toggle in audio settings.

### [ ] C29 Events and variety: weather, time of day, rotating modes
- **Why:** The Gridiron remaster plans Chaos as an event-only mode (R dev reply). Weather that changes gameplay (snow lowers traction) creates stories (Gx).
- **Accept:**
  - A weather mutator (clear/rain/snow) that tunes traction and catch radius, with visuals after A26.
  - A "featured mode of the week" slot in the casual queue, drawn from a list in a data file.

### [ ] C30 Netcode feel II
- **Why:** PLAN pillar 4 says "if it feels laggy, nothing else matters." `client_predictor.gd` ignores collisions and blocks, corrections snap with no smoothing, and no test runs under latency or loss. C03's moves make this worse.
- **Accept:**
  - Prediction includes athlete collisions and block engagement.
  - Corrections blend over about 100 ms.
  - `net_test.sh` gains a mode with injected 100 ms latency, 30 ms jitter and 2% loss. In it, the own-athlete position error stays under N yd and no action is lost.
  - Bandwidth per client is measured and logged.

---

## Addenda to existing backlog items (no new C id)
- **B01 Line play:** model it on Gridiron's shield (O "Blocking 3.0", 2021-10-26):
  - Shield energy is 100. Holding the shield drains it, and a bash costs 40.
  - A charged bash (held 2 s) slows the defender 15%.
  - A pancake knocks a "vulnerable" defender down for 0.75–2.25 s, and a successful bash gives a speed buff.
  - A dodged pancake gives the DL a free dash, and the DL gets a spin move.
  - Status icons show these states.
  - It must improve on Gridiron with the timing/leverage minigame in PLAN.
- **B04 Highlights:** add an auto TD replay with a skip vote, an MVP card at FINAL, a free-cam replay theater, and clip export (a frame range rendered via `shot.sh`-style capture to an image sequence or video). Gridiron promised replays and never shipped them, so this is an easy win.
- **B09 Kickoffs:** share the kick meter with C02. Onside is a C27 mutator, off by default (Gridiron removed it).
- **D02 Party:** party members queue together and stay on one team, up to the team size.
- **D03 Chaosball in matchmaking:** prefer one shared casual queue with a mode vote over a separate playlist (small-population lesson).
