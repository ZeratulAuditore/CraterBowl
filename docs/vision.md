# Crater Bowl: vision

The original pitch, pillars and roadmap (written as `PLAN.md`, 2026-11-24). The pillars and the problems → fixes table still guide every design call. The roadmap phases are history: what to build next lives in GitHub issues (`workflow.md`), and what shipped is in `features/` (history: merged PRs). The game is now named **Crater Bowl** (`features/out-of-game.md`).

Title: **Crater Bowl**.

An original online multiplayer arcade football game for 2–10 friends. It's a spiritual successor to the games that "have so much potential but are pretty bad right now."

## Assumptions (change these and the plan changes)
1. **PC first**, friends play online together. Couch/split-screen is a nice-to-have.
2. **Arcade, not a sim.** Short games (8–12 min), every player controls one athlete, and no roster management for now.
3. **Small team of friends**, part-time, with mixed skill: 1–2 coders, the rest doing design, art, audio and playtesting.
4. **Free to start.** You'd only think about selling it on Steam after it's fun.

## Design pillars
1. **Every snap is a story.** Plays are fast (~15s) and readable, and something interesting happens on most downs.
2. **Everyone matters.** Linemen, receivers and DBs all have a skill game, not just the QB.
3. **Easy to learn, deep to master.** 4 buttons to start, skill expression in timing and positioning.
4. **Netcode is a feature.** If it feels laggy, nothing else matters.

## What usually makes these games bad (and our fix)
| Common problem | Fix |
|---|---|
| Laggy, rubber-banding multiplayer | Server-authoritative ball + client-side prediction for your own player; build and test netcode in Phase 1, not last |
| Only the QB/ball carrier has fun | Line play minigame (leverage/hand-fighting timing), route-running stamina bursts, DB jam/press mechanic |
| Floaty, unreadable physics | Tuned arcade movement (accel/cut curves) instead of raw ragdoll; ragdoll is only cosmetic, after the whistle |
| Empty lobbies | Bots fill any empty slot, so 1v1 or 3v3 games still work |
| Nothing to come back for | Cosmetics, player stats/seasons among your friend group, replays/highlight clips |
| Confusing playcalling | 6–8 play cards per side, a 5-second huddle, a QB-only playbook |

## Tech recommendation
- **Engine: Godot 4 (GDScript).** It's free and lightweight, friends can install it in minutes, it has built-in high-level multiplayer, and it exports to Windows/Mac/Linux/Web. (Unity is the alternative if a friend already knows it. Don't pick Unreal for a small part-time team.)
- **Networking:** a dedicated headless Godot server (cheap VPS, ~$5/mo) running at 30 Hz. Clients predict their own player, and the server owns the ball, tackles and scoring. Start with ENet; add Steam relay later.
- **Art:** low-poly 3D, a stylized look (flat colors, chunky silhouettes). It's cheap to produce and ages well. Start with free CC0 packs (Kenney, Quaternius) and replace them later.
- **Collab:** a GitHub repo, Git LFS for assets, a Discord channel, and GitHub issues as the one shared backlog (`workflow.md`).

## Roadmap

### Phase 0: Kickoff (1 week)
- Each friend writes their top 5 frustrations with the old game and top 5 dream features. Merge them into a ranked list.
- Lock the pillars, team size per side, and target game length.
- Repo + Godot project skeleton + Discord.
- **Exit:** everyone agrees on the one-sentence pitch and the first 3 phases.

### Phase 1: "Toy" prototype (3–4 weeks)
Gray boxes on a field. Nothing pretty.
- Player movement (sprint, juke, stiff-arm) that feels good alone.
- Throwing: aim + charge + lead, catch radius, tackling.
- **Online 2v2 over the internet from day one** with the dedicated server.
- **Exit:** 4 friends play 20 minutes online and want to keep going. If it's not fun as gray boxes, fix the feel before adding anything.

### Phase 2: Real football (4–6 weeks)
- Downs, line of scrimmage, first downs, clock, scoring, kickoff/punt (simplified).
- Play-card huddle, ~6 plays per side.
- Line-play minigame and DB press.
- Bots for empty slots (simple: follow route / follow assignment / chase ball).
- **Exit:** a full 10-minute 5v5 game runs start to finish without bugs that stop play.

### Phase 3: Make it feel great (4–6 weeks)
- Low-poly art pass, animations, camera polish, hit-stop/screenshake on big hits.
- Crowd and commentary-lite audio stingers.
- Lobby/party system, rematch button, simple matchmaking among friends.
- Instant replay of the last play.
- **Exit:** an outside friend who's never seen it can learn it in one game.

### Phase 4: Reasons to return (ongoing)
- Persistent stats + a friend-group "season" leaderboard.
- Cosmetics (jerseys, celebrations), custom team creator.
- More modes: 3v3 backyard, 7v7, overtime shootout.
- Optional: Steam page, playtest key giveaway, Discord community.

## Who does what (suggested)
| Role | Owns |
|---|---|
| Netcode/gameplay lead (strongest coder) | Server, prediction, physics feel |
| Gameplay coder #2 | Rules engine (downs/clock/scoring), bots |
| Designer | Playbook, balance spreadsheet, running playtests |
| Artist/animator | Characters, field, UI |
| Audio + community | SFX, music sourcing, Discord, playtest scheduling |
| Everyone | **Weekly playtest night** (non-negotiable; this is the core loop of the project) |

## How we work
- Weekly playtest → 3-question survey (most fun moment, most frustrating moment, one change) → top 3 fixes become next week's work.
- Small PRs, `main` is always playable, tag a build before every playtest.
- Keep a `TUNING.md` / data file for all feel numbers (speeds, catch radius, tackle windows) so designers can tweak without code.

## Top risks
1. **Netcode is harder than expected.** Mitigation: it's Phase 1, not Phase 3, and tackles are server-decided.
2. **Scope creep (franchise mode, 11v11, licensed teams).** Mitigation: pillars + a "Later" list, no NFL licensing ever.
3. **Friend-team motivation fades.** Mitigation: playtest every week, so there's something new to play every Friday.
4. **Too similar to the original.** Mitigation: original name, art, UI and team branding; borrow genre ideas, not assets.

## Open questions for the group
1. Team size per side: 3v3, 5v5 or 7v7? (Recommend **5v5**.)
2. Camera: behind-the-player 3rd person, or broadcast side view?
3. Does anyone already know Godot or Unity? (This could flip the engine choice.)
4. Do you want couch play too, or online-only?
5. What exactly is "pretty bad" about the current game? Make the list in Phase 0 and turn each item into a row in the "problems → fixes" table.
