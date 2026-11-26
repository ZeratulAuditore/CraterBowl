# Feature docs

Feature level: what the player experiences **today** on `main`, including rules, controls, numbers, the decisions behind them, and what didn't work. Each doc ends with the open GitHub issues for its area (label `area:<name>`). For how things are built, see `../design/`. For how work is tracked, see `../workflow.md`.

| Doc | Area label | Covers |
|---|---|---|
| `offense.md` | `area:offense` | Passing, catching, routes, play calling / huddle, run game |
| `defense.md` | `area:defense` | Defensive playbook and calls, coverage, pre-snap roam, assignments and play art |
| `line-play.md` | `area:line-play` | Blocking, pass protection, pass rush |
| `movement.md` | `area:movement` | Running, sprint/stamina, dive, dash, spin and other moves |
| `kicking.md` | `area:kicking` | Kickoffs, tries, and the (planned) kicking game |
| `rules.md` | `area:rules` | Downs, scoring, clock, timeouts, turnovers, spotting, match sizes |
| `chaosball.md` | `area:chaosball` | The Chaosball mode |
| `bots.md` | `area:bots` | AI players filling empty slots |
| `online.md` | `area:online` | Hosting/joining, lobbies, queues, parties, server browser, ranked queue |
| `progression.md` | `area:progression` | Stats, leaderboards, ranked ratings, XP, cosmetics, achievements |
| `social.md` | `area:social` | Communication (voice chat planned, #31), spectators, text chat |
| `presentation.md` | `area:presentation`, `area:audio` | Stadium, athletes, camera, HUD/scorebug, music and audio |
| `replays.md` | `area:replays` | Match replays and highlights |
| `training.md` | `area:training` | Training ground, drills, practice |
| `out-of-game.md` | `area:ui`, `area:infra` | Name/brand, menus, settings, distribution |

Adding an area? Add a doc here, a matching `area:` label (`gh label create`), and a row in `../workflow.md`.
