# Presentation (graphics, camera, HUD, audio)

Feature-level doc: how a match looks and sounds for players **today** on `main`. Performance rules and budgets: `../optimization/README.md`. Layering (presentation reads sim state and owns no rules): `../design/architecture.md`. Open work: GitHub issues labelled `area:presentation` and `area:audio` (listed below).

## Summary
Matches are played in **Crater Bowl**, an original lunar stadium built inside a crater. Rigged CC0 athletes, a broadcast-style overlay and event effects (camera shake, tackle dust, touchdown fireworks) sit on top of a sim that knows nothing about them. The menus have a licensed music soundtrack. Matches have no sound effects yet.

The stadium screens show “PRIVATE MATCH LOBBY” while players are in the private lobby. When the
match starts, the screens show the score and the configured game clock.

## How it looks and plays
| Piece | What the player sees | Owner |
|---|---|---|
| Stadium | Bowl seating with an instanced crowd, LED ribbon boards, light towers, dome arches, jumbotrons, crater rim and regolith | `src/game/art/stadium.gd` |
| Field | Turf, lines, end zones, line-of-scrimmage barrier (see `defense.md`), sideline chains | `src/game/art/field_art.gd`, `los_barrier.gd`, `presentation.gd` |
| Athletes | Quaternius rig. Your team wears the CC0 mannequin and helmet, and opponents wear a custom uniform. Jersey numbers are `Label3D` on chest and back. Cosmetics are view-only. | `src/game/player.gd`, `art/character_art.gd`, `art/football_uniforms.gd` |
| Ball | Leather spheroid with laces, spiral, flight trail and a landing marker | `src/game/presentation.gd` |
| You | A team-colored ground ring marks the athlete you control. Nothing floats above your head. | `presentation.gd` |
| Camera | Follow camera behind your player. The mouse moves the aim range on the turf. Your ground ring always stays above the scorebug (#128). While you're the passer, an over-the-shoulder POV that keeps the line and backs in frame. | `src/game/main.gd` `_update_camera`, `_framed_look`, `_camera_target_yaw` |
| Effects | Camera shake on big events, tackle dust, touchdown fireworks, crowd excitement, jumbotron | `presentation.gd` |
| Overlay | Scorebug (possession, score, period and game clock, play clock, down and distance, timeout pips, ball spot, mode and mini field), status line, play-call picker, movement meters, hold-Tab scoreboard, event banners | `src/game/overlay.gd` |
| Play art | Routes, run paths, blocking targets and coverage drawn on the turf before the snap | `offense.md`, `defense.md` |
| Quality | `--gfx=low\|medium\|high`. Software rasterizers (llvmpipe etc.) auto-select `low`. | `src/game/art/quality.gd` |

**Scorebug.** The ball spot names the team whose territory contains the ball. The mini field reads
from the offense’s end toward the goal it attacks. Its cyan marker is the line of scrimmage and
its gold marker is the line to gain. The mini field appears during Classic scrimmage. Kickoffs and
conversion attempts have distinct labels. The period label follows the match rules, which use
halves today.

**HUD layout (#116).** The scorebug sits on the bottom edge at one fixed width: down & distance
takes the slack, so the bug doesn't jump when the play-clock cell hides at the snap. The movement
meters sit to its left. The status line is a small backed pill on the scorebug's top-left edge, so
nothing floats over the controlled player. After the whistle it summarizes the play in player words
(`TACKLED · +3`, `SACK · -5`, `OUT OF BOUNDS · +7`, `INCOMPLETE`, `INTERCEPTION`), not the raw whistle
code. The play-call picker uses the menu theme and is pinned top-right, over the sky. Replay key
hints are a backed bar of key + action pairs just above the scorebug. Post-game, only the featured
player stands on stage while their stat card is up, and the hint is a backed pill in the corner.

**Audio today:** only the menu soundtrack. It plays `assets/music/tracks.json` in order, loops the playlist, and has a "now playing" widget (prev / pause / next). Credits are in `assets/music/CREDITS.md`. Volume follows the music and master settings. A match plays no SFX, crowd or whistle (#22).

## Design decisions
- **Original look only.** It's a sci-fi lunar dome, never Gridiron's art or UI. Assets must be CC0 or compatible-license, logged in `ASSETS.md`.
- **Presentation never owns rules.** Views mirror sim state and are interpolated per render frame, so the sim stays deterministic and testable headless.
- **Rigged athletes are the most expensive thing on screen** (about 8 ms each on WSL's GL path). Measure before adding bones or characters. Details: `../optimization/README.md`.
- **No floating marker over your player (#141).** A spinning cyan chevron used to hover above the controlled athlete. The owner removed it: you can never switch athletes (your seat is fixed for the match, position changes are rejected and Tab only shows the scoreboard), so there is no switch to re-find yourself after. The team-colored ground ring stays as the "you" marker. #12 plans rings for every athlete, with yours kept distinct.
- **The camera frames you above the HUD; the HUD doesn't move (#128).** The follow camera looks at the aim point (your player + aim range downfield), so a long aim range, a dead-ball whistle or backpedalling toward the lagging camera used to drop your ring to y≈630–760 of 720, behind the scorebug (top ≈623). `_framed_look` now pitches the look down just enough that the ring's near edge sits no lower than `FRAME_FEET_MAX` (0.80 of the screen height, ~576 px at 720p, clear of the status pill). It's exact geometry from the camera's real position, so it holds for any `FOLLOW_CAM_OFFSET` (a #140 zoom only has to scale it), FOV and follow lag, and it's a no-op when the look already frames you. Rejected: moving or shrinking the scorebug (the #116 layout is the fix for the HUD side; #176/#216 edit it), and raising the follow camera (changes the stands-safety distance #140 depends on, and a far aim range still pushes you down).
- **POV sits back 5.4 yd, 2.8 high (#128).** At 4.2 back / 2.6 high the near back (#13, 4 yd across) was cut at the bottom-right edge. Wideouts 18 yd out are outside the POV frame on purpose; you find them by turning the aim. The passer's own ring stays below the HUD in POV: getting it up there means pitching the view down, and the POV pitch is the throw's launch angle, so the follow-camera rule doesn't apply.
- **HUD text refreshes at about 10 Hz.** Rebuilding scorebug strings every frame cost ~1 ms/frame (`../optimization/LOG.md`). Animated parts (throw bar, banners) still run per frame.

## Code and tests
- `src/game/presentation.gd`: ball, markers, effects, crowd, jumbotron
- `src/game/overlay.gd`: scorebug and HUD
- `src/game/player.gd`: athlete views
- `src/game/art/`: stadium, field, materials, shaders, quality presets
- `src/game/render_cache.gd`: shared low-poly meshes and materials (lint forbids default-tessellation meshes)
- `src/ui/music_player.gd`: menu soundtrack
- Tests:
  - `tests/render_budget.gd` and `tests/test_render_perf.gd` cap tris, instances, shadows, materials and skinned meshes (`./scripts/perf.sh`)
  - Visuals are verified with `./scripts/shot.sh` PNGs (`../TESTING.md`)
  - `tests/game_flow.gd` exercises the live overlay. `./scripts/visual_test.sh` checks and captures the scorebug in scrimmage, kickoff and conversion states, and `tests/visual/you_marker_test.gd` checks the ground ring (and no floating chevron) in a match, an instant replay and the training ground.
  - `tests/visual/camera_framing_test.gd` (#128) projects your ring to the screen and asserts it sits above the scorebug pre-snap on defense, every frame of a backpedal at max aim range, and at a sack's whistle; and that every offensive teammate within 8 yd of the QB is whole in the pre-snap POV. `tests/test_main_scene.gd` checks `_framed_look` across camera distances, FOVs, aim ranges and lag.
  - `tests/visual/hud_polish_test.gd` asserts the fixed scorebug width (presnap, live, whistle), the dead-ball summary, the status pill clearing the scorebug, the themed picker pinned top-right and the meters beside the bug.

## Open issues
- #10 C10 Throw readability: landing marker, aim-zoom
- #12 C31 Who's who on the field: nameplates, rings, "you" marker
- #22 C16 Audio foundation + live play feed
- #31 Team voice chat (team-only, host-relayed)
- #34 C33 Team identity: names, colors, field branding, "ball on <TEAM> 19"
- #38 B06 Juice: hit-stop, screenshake, crowd stingers
- #43 C28 Commentary barks
- #44 C29 Events and variety: weather, time of day, rotating modes
