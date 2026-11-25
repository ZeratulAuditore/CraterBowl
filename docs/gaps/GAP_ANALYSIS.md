# Gap analysis

Last evaluated: **2026-11-25** (baseline, see `reviews/2026-11-25.md`). State of `main` at `9b9ff79` (iter 026), plus uncommitted A26/A27 worktrees.

Source tags:
- **O** = shipped in the original Gridiron (patch notes 2020–2022)
- **R** = Gridiron Remastered store page / open beta (since 2026-11-02)
- **R?** = original feature not yet confirmed in the remaster
- **Gx** = other genre games (Blitz, MFL, Madden The Yard, Rocket League, Rematch, Retro Bowl, Axis, Legend Bowl)

"Ours" describes what's actually in the code, not what's checked off.

## Headline
The A-list parity items are checked off and tested. However, the A-list was written from Gridiron's store blurb, and a real Gridiron match has a lot the blurb doesn't mention:
- **Our game is pass-only.** There are no handoffs or run plays, no kicking game (the kickoff is an automatic reset to the 25), no timeouts and no penalties.
- **Ball carriers and blockers have no moves.** Gridiron's line play is a resource game (shield energy, bash, pancake, DL spin). Ours is an automatic engage with no input.
- **The out-of-game layer is missing.** There is no audio, gamepad, menu, settings, chat, spectating, reconnect or party. A27 is in progress but nothing is merged yet.
- **Online only works on a LAN or with open ports.** The invite code is just an encoded IP:port, and the host is trusted for XP, ratings and leaderboards.

## Matrix

### Core controls & moves
| Feature | Ref | Ours | Gap → |
|---|---|---|---|
| Run/sprint/stamina | O | yes (stamina lockout) | none; stamina bar color is A27 |
| Jump, stamina drain on chained jumps | O | no | C03 |
| Ball-carrier dive / dash (side dash, costs stamina) | O | no (dive is tackle-only) | C03 |
| Spin / juke / stiff-arm / hurdle / truck | Gx (Madden, CFB, Legend Bowl), O (DL spin) | no (bot sidestep only) | C03 |
| Look-behind, free-look, ball cam, QB 1st/3rd person | O | follow cam only | C19 |

### Passing & catching
| Feature | Ref | Ours | Gap → |
|---|---|---|---|
| Aim + charge, leading, lob | O/R | yes | none |
| Ball landing marker / throw indicator | O | no | C10 |
| Aim-zoom throw | O | no | C10 |
| Toe-tap: catch counted where the feet land | O | no (out of bounds = incomplete) | C07 |
| Batted passes at the line (contact within 5 yd = incomplete) | O | no | C07 |
| Dive / jump catches | O (jump-spam meta), Gx | no (catching is automatic) | C03 + C07 |
| QB slowdown deep in the backfield (anti-scramble) | O | no | C05 |
| Laterals / backward passes / pitch | Gx (The Yard) | no (one forward throw per play) | C01, C27 |

### Run game
| Feature | Ref | Ours | Gap → |
|---|---|---|---|
| Handoff (animation, re-handoff cooldown, stamina immunity) | O | **no** | **C01** |
| Run plays in the playbook, RB carries | O | **no** (6 pass plays) | **C01** |

### Blocking & line play
| Feature | Ref | Ours | Gap → |
|---|---|---|---|
| Shield blocking (energy, bash, charged bash, pancake, status icons) | O | auto-engage, no input | **B01 addendum** |
| DL spin move; free dash after a dodged pancake | O | no | B01 addendum |
| Blockers limited to 5 yd past the line until a pass or run | O | no | C05 |

### Defense
| Feature | Ref | Ours | Gap → |
|---|---|---|---|
| Diving / collision tackles, sacks, TFL | O | dive tackle; sack stat | none |
| Pre-snap free roam (except DL) | O | positions clamped | C08 |
| Defensive play calls, zone coverage, blitz assignments | O (play art shows zone/blitz) | man coverage only, no defensive calls | **C08** |
| Visual play art for every assignment | O | offense routes only | C08 |
| Press / jam | PLAN | no | B02 |

### Special teams
| Feature | Ref | Ours | Gap → |
|---|---|---|---|
| Coin toss | O | no | C02 |
| Kickoff with power meter + returns | O | automatic reset to the 25 | **B09** |
| Punt + punt return | O | **no** (4th down = go or turn over) | **C02** |
| Field goals, PAT kicks, FG block, scoop-and-score | O | **no** (tries from scrimmage only) | **C02** |
| Onside kick | Gx (Blitz/MFL); O removed it | no | C27 |

### Rules, clock, penalties
| Feature | Ref | Ours | Gap → |
|---|---|---|---|
| Configurable quarter length | O | fixed halves | C04 |
| Timeouts, one-minute warning | O | **no** | **C04** |
| Clock runs between plays (clock management) | O/real football | clock stops between plays | C04 |
| Mercy rule, forfeit vote | O | no | C04, C11 |
| Overtime | — | no | B10 |
| Ineligible receivers (linemen), intentional grounding | O (competitive ruleset) | C/OL ineligible only | C05 |
| Offsides / false start / delay of game | real football | impossible by construction (clamped / auto-snap) | C05 (decide: keep impossible?) |
| Ref console in custom matches | O | no | C21 |

### Positions & roles
| Feature | Ref | Ours | Gap → |
|---|---|---|---|
| QB/captain calls plays, formations, audibles | O | QB cycles 6 plays; no formations or audibles | **C09** |
| QB vote with QBR, half-time re-vote, mutual swap | O | first-come TAB cycling | C12 |
| Role queue (role points earned by playing line) | O | no | C12 |

### Modes
| Feature | Ref | Ours | Gap → |
|---|---|---|---|
| 3v3/5v5/7v7, casual, ranked, private, practice, Chaosball | O/R | yes | none (D03: Chaosball not in matchmaking) |
| Chaosball double jump, dash-down, dive-cancel | O | no | C03 addendum |
| 1v1 catching race (first to 15 vs. a robot QB) | O | no | C17 |
| Tutorial | O | no (drills only) | C18 |
| Limited-time event modes | R (dev: Chaos only at events) | n/a | C29 |

### Online, social, trust
| Feature | Ref | Ours | Gap → |
|---|---|---|---|
| Party queue (stays on the same team) | O | no | D02 |
| Reconnect into the same slot; leaver/dodge penalties | O, Gx (Rocket League) | rejoining counts as a new join | **C11** |
| Server browser for public custom lobbies | O | no | C15 |
| NAT traversal / relay / dedicated server | O (GameLift) | raw IP code; host plays | B07 + C15 |
| Text chat (all/team/party), mute | O | no | C13 |
| Quick-chat / ping wheel by position | O, Gx (Rocket League) | no | **C13** |
| Voice chat (push-to-talk) | O | no | C13 (later; Discord is fine for friends) |
| Spectators (up to 4, cycle cam, jump to QB) | O | no | C14 |
| Report / mute / kick, chat filter | O | no | C21 |
| Server-authoritative progression (XP, ratings, boards) | O (backend) | host trusts itself; clients trust their own XP | C22 |
| Rematch / re-run teams vote | Gx (Rocket League, Rematch) | no | C20 |

### Progression & stats
| Feature | Ref | Ours | Gap → |
|---|---|---|---|
| Levels/XP, ranked seasons, per-position boards | O | yes | none |
| Placements, hidden MMR, new-player protection | O; top complaint #5 | provisional K only | C23 |
| Match history (50), profile, QBR | O | no | C24 |
| Achievements | O (42), R | no | D04 |
| Return yards | — | not tracked | C24 |

### Presentation & audio
| Feature | Ref | Ours | Gap → |
|---|---|---|---|
| Stadiums, lighting, animations | R (UE5) | A26 in progress | A26 |
| Crowd reactions, whistle, INT / broken-block stings | O | **no audio at all** | **C16** (+ B06 juice) |
| Live play feed | O | HUD text line | C16 |
| Commentary barks | Gx (MFL, Blitz) | no | C28 |
| Weather / time of day | Gx | no | C29 |

### Settings & accessibility
| Feature | Ref | Ours | Gap → |
|---|---|---|---|
| Gamepad, rebinding, audio/video settings | O/R | A27 in progress | A27 |
| Colorblind team outlines, FOV, effects reduction, streamer mode, UI hue | O | no | C19 |

### Better-than-Gridiron (genre)
| Idea | Ref | Gap → |
|---|---|---|
| Momentum / "on fire" streaks | Gx (Blitz, NBA Jam) | C25 |
| One-passive archetypes (arm, speed, tank, ballhawk) | Gx (The Yard, CFB25) | C26 |
| Backyard rules / trick plays (laterals, snap to anyone, onside any time) | Gx (The Yard, MFL) | C27 |
| Mutator panel for private lobbies (gravity, score values, quarter length, Chaosball knobs) | Gx (Rocket League), B08 | C21 |
| Highlight reel, MVP card, clip export, free-cam theater | Gx (Rocket League) | B04 addendum |
| Friend-group league with standings | Gx (Axis) | B05 |
| Netcode: collision-aware prediction, smoothed corrections, lag/loss tests | PLAN pillar 4 | C30 |

## Lessons from Gridiron's complaints (design guardrails, not TODOs)
1. The game got pulled into a paid/closed beta, then moved stores and went dark. **Keep a self-hostable build** (we already are; don't lose it).
2. New players got matched against 500-hour veterans → C23.
3. The "Hail Mary simulator" meta (scramble, throw deep, everyone spams jump) → C05's QB slowdown, contested-catch tuning in C07, and the known "deep passes too easy vs bots" issue.
4. Toxicity and bans people saw as unfair → C21 moderation stays simple and local (host kick and mute) before any ban system.
5. Small player base and long queues → don't split queues. Bots backfill, and Chaosball shares the casual queue.
