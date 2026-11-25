# Gap TODOs (Phase C)

Ordered by priority, so take items top to bottom. Each item is scoped, not designed; the real design pass happens in `docs/iterations/NNN-*.md` when the loop picks it up. Acceptance criteria are written so they can become tests (`tests/test_*.gd`, `game_flow.gd`, `net_client.gd`). If an item is too big for one iteration, split it here (C01a, C01b) and do the first half.

Source tags:
- **O** = original Gridiron
- **R** = Gridiron Remastered
- **R-ss** = seen directly in the user's remaster open-beta screenshots (build 6763c93, 2026-11-25)
- **Gx** = genre game
- **PLAN** = our PLAN.md

See `GAP_ANALYSIS.md` for the matrix and `reviews/` for URLs.

## Recommended build order (revised 2026-11-25 after the screenshots)
The screenshots show the remaster's every-snap loop: **play-call screen → break → pre-snap play art on the turf → snap**, with the full scorebug always on screen. Kickoffs are live plays. Ours: press Q to cycle plays → text HUD → snap, with an instant kickoff reset. What a player sees and does before every snap is our biggest gap, so take these first:
1. **B03 play-call huddle + C08 defensive calls/zones**, built together, so both sides call plays and see their own assignments.
2. **B09 kickoffs + C02 punts/FGs**, which share the kick meter.
3. **C01 run game.**
4. **C04 clock**: quarters, timeouts, running clock.
5. **C31 nameplates + scorebug checklist** (handed to A26/A27).
6. **C32 co-op vs bots.**

After that, follow the list order below. B01/B02 (line play, press) come after these, since they deepen mechanics the remaster already has in simpler form.

---

## P0: core football a player notices in match one

### [x] C01 Run game: handoffs, run plays, RB carries (iter 033)
- **Why:** Gridiron had animated handoffs with a re-handoff cooldown and 2 s of stamina immunity (O 1.0.3.52/53). Ours is pass-only, so RBs and OL have nothing to do on most plays. This is the single biggest feel gap.
- **Accept:**
  - QB can hand the ball to an adjacent back with an action key. Possession transfers in the sim, and a second handoff is blocked by a cooldown.
  - The playbook gains at least 2 run plays (inside zone, outside sweep) with blocking assignments. Bot RBs follow the run path, and bot OL block for it.
  - A run past the line keeps the play live. Stats credit rushing attempts and yards to the RB.
  - Bots call run plays some fraction of the time, and the 2-min bot game still finishes with a sane score.
- **Touch:** `world.gd` (possession transfer), `routes.gd` (plays), `ai.gd`, `stats.gd`, `protocol.gd` (whitelist `handoff`).

### [~] C02 Kicking game: coin toss, punts, field goals, PAT kicks (claimed: claude 2026-11-25, with B09; branch kicking-game)
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
  - **Remaster (R-ss):** 4 short quarters (the clock showed 4th 1:19 and 1:11) and 3 timeout pips per team on the scorebug.
    - Add a quarters option. Halftime stays after Q2, and teams switch direction each quarter.
    - Timeouts remaining must always be visible.
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

### [x] C08a Defensive playbook and situational suggestions
- **Accept:** Define at least eight man, zone and blitz calls across base, goal-line and prevent shells.
- **Accept:** Suggest a goal-line call near the end zone and a prevent call on long late downs, with a base fallback.
- This catalog supplies the defensive side of B03. Apply assignments in the sim and expose them in the huddle and on-field art in the remaining C08 items.

### [x] C08b Defensive play selection and synchronization
- **Accept:** Each classic snap starts with the suggested defensive call. The defending team can select any catalog call during presnap, and the selection is synchronized to clients.
- The huddle control, on-field assignments and bot behavior follow in C08c.

### [x] C08c Defensive assignments, coverage, blitzes and play art

### [x] C08d Pre-snap defensive roam + LOS barrier (plan: docs/iterations/032-presnap-defense-roam.md)
- **Why:** In the reference, defenders spawn in stance and press Space to break it and roam pre-snap. DL stay set. A see-through animated hex wall at the LOS marks the limit. Ours: everyone (DL too) can already move pre-snap, they hit an invisible clamp, and Space on defense does nothing.
- **Accept:** Defense lines up locked. Space breaks stance for LB/CB/S only. The neutral-zone clamp is shared by host and client prediction. The barrier is visible pre-snap with proximity reveal and contact ripples, and dissolves at the snap.
- Splits the "non-DL defenders can move freely" bullet out of C08b, so it can ship independently of the playbook work (C08a).
- **Why:** Gridiron draws every player's assignment on the field: routes, blocks, man or zone, and blitz lane (O 1.0.4.47). Defense has pre-snap free roam (except DL). We have man coverage only, no defensive calls, and play art only for offense. That violates pillar 2 ("everyone matters").
- **Remaster screenshots (R-ss, 2026-11-25):**
  - Every defensive snap starts with a play call.
  - Plays are filtered by Zone / Man / Blitz, and each one is a *call × shell*: "Zone Blitz / Cover 2 Deep", "Run Stop / Goal Line Defense", "Man Zone / Prevent 3 Deep". The shells are situational (goal line, prevent).
  - Pre-snap, each defender's zone is projected on the turf as an ellipse, drawn in a different color for underneath hook/curl zones than for flat/deep zones. A tether line runs from the player to the zone, and blitzers get red arrows on the turf. On Gridiron this play art is how 7 strangers coordinate without voice.
- **Accept (added):**
  - Defensive calls = coverage family (man / zone / blitz) × shell (base, goal line, prevent), with at least 8 calls in total.
  - The goal-line and prevent shells become the suggested defaults when the down/distance/field position fits.
  - Zone landmarks are drawn on the turf in 3D, along with the tether and blitz arrows, visible to your own team only.
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
- **Remaster (R-ss):** the play-call screen shows every teammate's name on their slot in the diagram, and you can "drag a player to swap". Position shuffling happens inside the huddle, not in a lobby. Accept (added): the QB/captain can swap two teammates' slots from the play-call screen, and the swapped players get a one-tap confirm.
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
  - The lobby has settings for: gravity, quarter length, score values, pass-clock length, bounce cap, mercy rule, kicking on/off, and **line to gain** (10 yd default; the remaster plays 1st & 15, per R-ss).
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

### [ ] C31 Who's who on the field: nameplates, rings, "you" marker
- **Why:** In every remaster screenshot (R-ss) each athlete has a floating name and a team-colored ground ring, and your own ring is highlighted. Ours shows only jersey numbers (`player.gd` `number_front/back`). With 7 humans per side, you can't call "hit Ben on the slant" if you can't see who Ben is.
- **Accept:**
  - Each athlete shows a name tag from roster/lobby names; bots show their bot name.
  - Ground rings in the team color, with your own ring distinct.
  - Opponent names are optional (host setting) and hidden in streamer mode (C19).
  - Tags fade with distance and never cover the ball carrier.
  - Verified with `shot.sh` PNGs.
  - **Coordinate with A26** (graphics session owns `player.gd` visuals). If A26 is still open, hand this to them as a request rather than building it in parallel.

### [ ] C32 Co-op vs bots playlist + bot difficulty
- **Why:** The remaster's open-beta scorebug reads "7 VS BOTS": a matchmade mode where humans team up against a full bot side. With a small population that's the queue that always fires (our small-population lesson). The opposing bots carry gamer-style generated names, so the mode doesn't feel empty. Ours: co-op only works by hand (team swap in a private lobby, PARITY G24).
- **Accept:**
  - The matchmaker offers a `coop` queue. It forms a match from 1 to N humans all on one team and fills the other side with bots, starting without waiting for a full lobby.
  - Bot difficulty (easy/normal/hard) tunes reaction time, coverage tightness and throw accuracy. A bot sim shows the win-rate ordering is monotonic.
  - Bots get generated, original names.
  - Co-op results give XP but never touch ranked.

---

## P2: better than Gridiron, and polish

### [ ] C33 Team identity: names, colors, field branding, "ball on <TEAM> 19"
- **Why:** The remaster (R-ss) has named teams (Coolers vs Bolts) with logos, team-colored end-zone wordmarks and scorebug panels. Field position reads "BALL ON COOLERS 19" instead of "own/opp". The original let players set custom team names and abbreviations (O). Identity is cheap and gives friend groups something to own.
- **Accept:**
  - A data file of at least 8 original team identities (name, abbreviation, two colors, a procedural or CC0 logo).
  - The host picks or randomizes teams, which drive uniforms, end-zone text and HUD.
  - Spot text uses the team abbreviation ("BALL ON BOL 19").
  - Private lobbies can set custom names (sanitized).
  - After A26. Ours must not resemble their teams.

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
  - Remaster (R-ss): the kickoff is a real live play, with a stepped power meter beside the kicker and the ball on a tee.
  - The kicking team spreads across the field, and the receivers line up as a front row plus two deep returners. A "KICKOFF" banner replaces down & distance.
  - Our `_kickoff()` is still an instant reset, so B09 is now confirmed parity (not "better than") and should move ahead of B01/B02.
- **B03 Play-call huddle:** this is the remaster's *every-snap* screen (R-ss).
  - **Their layout:** a large overlay with a play list and filter tabs, a "LAST" quick-recall row, and a full-field diagram that puts teammate names on their slots and draws the zones and blitz arrows. It also has a FLIP (mirror) button, a "choose the best play for me" button with a "do this every play" checkbox, a countdown, and a BREAK button. Players stand in a 3D huddle meanwhile.
  - **Ours:** the QB presses Q to cycle 6 plays, shown as HUD text, so this is now the most visible gap.
  - **Build ours to beat theirs on speed (pillar: 5 s huddle):**
    - 6–8 situational cards, not a long scroll list.
    - A smart default pre-highlighted from down, distance and field position, so one key accepts it.
    - Last-play recall and flip.
    - An auto-call opt-in per player, which doubles as an accessibility feature.
    - The diagram shows *your* assignment large and the others small.
    - Non-callers see the chosen play as soon as it's picked.
  - Don't copy their layout or styling (left list + right diagram, purple/neon). Use our own A27 visual language.
- **A26/A27 scorebug requirements** (owned by the graphics overlay; hand over as a checklist):
  - possession marker
  - quarter and clock
  - play clock
  - timeouts left per team
  - down & distance (and KICKOFF/TRY states)
  - spot text with team name
  - mode label (e.g. "5v5 CO-OP")
  - a mini field-position strip showing the LOS and the line to gain
  - The remaster shows all of these in one compact strip. Ours shows them as a single HUD text label.
- **D02 Party:** shipped iter 028 (parties matched as units, never split). The remaining gap is to also keep the party together across a rematch (C20).
- **D03 Chaosball in matchmaking:** shipped iter 029.
