# Legacy backlog IDs → GitHub issues

Until 2026-11-25 the backlog lived in `FEATURES.md` (A/B/D ids) and `docs/gaps/TODO.md` (C ids). It now lives in GitHub issues (migration: #1). Old ids still appear in commit messages, old PRs and code comments; use this table to resolve them. **New work never gets a letter id**: the issue number is the id.

## Open items (migrated)

| Legacy | Issue | Title |
|---|---|---|
| B09 | #2 | B09 Real kickoffs and returns (closed: shipped iter 035) |
| C02 | #3 | C02 Kicking game: coin toss, punts, field goals, PAT kicks (closed: shipped iter 035) |
| C04b | #4 | C04b Four-quarter format and configurable periods |
| C03 | #5 | C03 Movement moveset: jump, dive, dash, spin, stiff-arm |
| C04c | #6 | C04c Switching ends, mercy rule and clock actions |
| C05 | #7 | C05 Competitive rules: eligibility, grounding, blocking zone, QB slowdown |
| C06 | #8 | C06 Spotting: forward progress, return yards, fumble variety |
| C07 | #9 | C07 Catch rules: toe-taps, batted balls, catch button, dive/jump catches |
| C09 | #10 | C09 Offense depth: formations, audibles, hot routes, pre-snap motion |
| C10 | #11 | C10 Throw readability: landing marker, aim-zoom |
| C31 | #12 | C31 Who's who on the field: nameplates, rings, "you" marker |
| — | #13 | Scorebug: show the full remaster-style checklist in one compact strip |
| C32 | #14 | C32 Co-op vs bots playlist + bot difficulty |
| B01 | #15 | B01 Line play minigame (leverage / hand-fighting timing, shield resource) |
| B10 | #16 | B10 Overtime for tied games |
| C11 | #17 | C11 Reconnect, leavers, forfeit |
| C12 | #18 | C12 Position assignment: QB vote, role preferences |
| C13 | #19 | C13 Communication: quick-chat wheel, pings, text chat |
| C14 | #20 | C14 Spectators |
| C15 | #21 | C15 Find a game without port-forwarding: dedicated server + browser |
| C16 | #22 | C16 Audio foundation + live play feed |
| C17 | #23 | C17 1v1 Catching mode |
| C18 | #24 | C18 Guided tutorial |
| C19 | #25 | C19 Accessibility & camera options |
| C20 | #26 | C20 Rematch and keep-the-lobby |
| C21 | #27 | C21 Host tools: mutators, ref console, kick/mute |
| C22 | #28 | C22 Trustworthy progression |
| C23 | #29 | C23 New-player protection |
| C24 | #30 | C24 Match history and profile |
| — | #31 | Team voice chat (team-only, host-relayed) |
| B07 | #32 | B07 NAT relay for CGNAT/strict routers + hosted public matchmaker |
| — | #33 | Gamepad: right-stick aiming |
| C33 | #34 | C33 Team identity: names, colors, field branding, "ball on <TEAM> 19" |
| B02 | #35 | B02 DB press / jam mechanic |
| B04 | #36 | B04 Instant replay + highlight clips (remaining scope after B04a) |
| B05 | #37 | B05 Friend-group seasons + persistent stats |
| B06 | #38 | B06 Juice: hit-stop, screenshake, crowd stingers |
| B08 | #39 | B08 Tuning data file editable without code |
| C25 | #40 | C25 Momentum / "on fire" |
| C26 | #41 | C26 Archetypes (one passive each) |
| C27 | #42 | C27 Backyard rules / trick plays |
| C28 | #43 | C28 Commentary barks |
| C29 | #44 | C29 Events and variety: weather, time of day, rotating modes |
| C30 | #45 | C30 Netcode feel II |
| — | #46 | Windows exe icon (rcedit) |
| — | #47 | UPnP failure notice appears after the match instead of in the lobby |
| — | #48 | Decide: host the public matchmaker (VPS/AWS + DNS)? |
| — | #49 | Decide: storefront (itch.io first vs Steam) |
| — | #50 | Decide: code signing / notarization |
| — | #51 | Triage legacy per-iteration "Known gaps" in ITERATIONS.md |

## Shipped or folded (no issue)

| Legacy | Outcome |
|---|---|
| A01–A28 | shipped (Phase A, Gridiron parity: iters 001–031; audit PASS in `docs/PARITY.md`) |
| B03 | shipped iter 032 (play-call huddle) |
| C01 | shipped iter 033 (run game) |
| C04a | shipped iter 034 (running clock, timeouts) |
| C08a | shipped iter 030 (defensive playbook) |
| C08b | shipped iter 031 (defensive selection + sync) |
| C08c | shipped iter 032 (assignments, coverage, play art) |
| C08d | shipped (pre-snap defensive roam + LOS barrier, `docs/features/defense.md`) |
| D01 | shipped with A27 (gamepad/InputMap) |
| D02 | shipped iter 028 (party queue); rematch remainder → #26 |
| D03 | shipped iter 029 (Chaosball queue) |
| D04 | shipped iter 030 (achievements) |
| D05 | folded into #8 (C06 spotting/return yards) |
| D06 | #67 kicking stats (filed by the kicking session during the migration) |
| D07 | #68 kick meter art |
| D08 | #69 fair catch + bot 2-pt |
| TRN | shipped (training ground, `docs/features/training.md`) |

Issue #1 is the migration itself. Items without a legacy id came from `docs/OUT_OF_GAME.md` known gaps and open decisions, the TODO.md addenda, and new requests (voice chat #31).
