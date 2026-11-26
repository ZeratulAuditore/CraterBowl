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
| Athletes | Quaternius rig. Your team wears the CC0 mannequin and helmet, and opponents wear a custom uniform. The open helmet hangs on the `Head` bone and wraps the skull down to its base in every clip, with the face in the opening. Jersey numbers are `Label3D` on chest and back. Cosmetics are view-only. | `src/game/player.gd`, `art/character_art.gd`, `art/football_uniforms.gd` |
| Ball | Leather spheroid with laces, spiral, flight trail and a landing marker. A carrier holds it in a tucked right arm, high on the chest; a QB holding before the throw holds it centered in front of the chest, one hand on each side (#244). | `src/game/presentation.gd`, `src/game/art/athlete_pose.gd` |
| You | A team-colored ground ring marks the athlete you control. Nothing floats above your head. | `presentation.gd` |
| Camera | Follow camera behind your player. The mouse moves the aim range on the turf. Your ground ring always stays above the scorebug (#128). While you're the passer, an over-the-shoulder POV that keeps the line and backs in frame. | `src/game/main.gd` `_update_camera`, `_framed_look`, `_camera_target_yaw` |
| Effects | Camera shake on big events, tackle dust, touchdown fireworks, crowd excitement, jumbotron | `presentation.gd` |
| Overlay | Scorebug (possession, score, period and game clock, play clock, down and distance, timeout pips, ball spot and mini field), status line, play-call picker, movement meters, hold-Tab scoreboard (with the match mode and size), event banners | `src/game/overlay.gd` |
| Play art | Routes, run paths, blocking targets and coverage drawn on the turf before the snap | `offense.md`, `defense.md` |
| Quality | `--gfx=low\|medium\|high`. Software rasterizers (llvmpipe etc.) auto-select `low`. | `src/game/art/quality.gd` |

**Scorebug.** The ball spot names the team whose territory contains the ball. The mini field reads
from the offense’s end toward the goal it attacks. Its cyan marker is the line of scrimmage and
its gold marker is the line to gain. The mini field appears during Classic scrimmage. Conversion
attempts read `TRY FOR N`. Kickoffs and the coin toss leave the down cell empty: they have no down
(#131). The period label follows the match rules, which use halves today. The play clock turns
orange-red at 5 s only when your team has the ball (#168). Training and practice show their drill
title under the bug, and the queue search shows there while you warm up.

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
- **The helmet is fitted at runtime, in Head-bone space (#158).** `InnersceneHelmet.glb` as built by `tools/characters/build_uniforms.py` perched on the crown: its shell rode about 0.2 high and was 1.8x the skull's width. `football_uniforms.gd` scales it by 0.75 and drops it 0.106 so the shell's inside clears the crown by about 7 mm, covers the back of the head to the skull base and keeps every cranium vertex inside (median clearance about 1.4 cm). The helmet hangs directly on the `Head` `BoneAttachment3D`, not on the yard-sized gear holder: the holder's 1/MODEL_SCALE made the same fit 7% too small and pushed the scalp through the crown. Fixing it at runtime kept the GLB and Blender recipe untouched. Shrinking or hiding head vertices was not needed, because no cranium vertex reaches the shell in any sampled clip. The opponent uniform's helmet is skinned into its own mesh and was not changed.
- **No floating marker over your player (#141).** A spinning cyan chevron used to hover above the controlled athlete. The owner removed it: you can never switch athletes (your seat is fixed for the match, position changes are rejected and Tab only shows the scoreboard), so there is no switch to re-find yourself after. The team-colored ground ring stays as the "you" marker. #12 plans rings for every athlete, with yours kept distinct.
- **The camera frames you above the HUD; the HUD doesn't move (#128).** The follow camera looks at the aim point (your player + aim range downfield), so a long aim range, a dead-ball whistle or backpedalling toward the lagging camera used to drop your ring to y≈630–760 of 720, behind the scorebug (top ≈623). `_framed_look` now pitches the look down just enough that the ring's near edge sits no lower than `FRAME_FEET_MAX` (0.80 of the screen height, ~576 px at 720p, clear of the status pill). It's exact geometry from the camera's real position, so it holds for any `FOLLOW_CAM_OFFSET` (a #140 zoom only has to scale it), FOV and follow lag, and it's a no-op when the look already frames you. Rejected: moving or shrinking the scorebug (the #116 layout is the fix for the HUD side; #176/#216 edit it), and raising the follow camera (changes the stands-safety distance #140 depends on, and a far aim range still pushes you down).
- **POV sits back 5.4 yd, 2.8 high (#128).** At 4.2 back / 2.6 high the near back (#13, 4 yd across) was cut at the bottom-right edge. Wideouts 18 yd out are outside the POV frame on purpose; you find them by turning the aim. The passer's own ring stays below the HUD in POV: getting it up there means pitching the view down, and the POV pitch is the throw's launch angle, so the follow-camera rule doesn't apply (#228).
- **HUD text refreshes at about 10 Hz.** Rebuilding scorebug strings every frame cost ~1 ms/frame (`../optimization/LOG.md`). Animated parts (throw bar, banners) still run per frame.
- **The live HUD carries only what you play by (#131).** The owner asked to drop everything else from the in-match HUD:
  - **No mode line** (`5V5 CLASSIC  ·  RANKED`) under the scorebug. You picked the mode before the match, so it moved to the top line of the hold-Tab scoreboard. Drill titles and the queue search still show there because they change what you're doing.
  - **No phase words in the down cell.** `KICKOFF` and `COIN TOSS` used to fill it. The cell is down & distance, and a kickoff has none, so it stays empty and the bug keeps its width. The Tab board still names the phase.
  - **The toss pill has no key hints.** It reads `YOU WON THE TOSS` or `<TEAM> IS CHOOSING`. The owner disliked `PRESS 1 TO RECEIVE OR 2 TO KICK` on the HUD. Removing it can't strand anyone: no answer in `TOSS_WINDOW` (5 s) means receive, the usual pick. The choice stays discoverable in the controls list (`1` "Extra point / toss: receive", `2` "Two-point try / toss: kick"). The coin-toss cutscene (#129) will own the toss moment and its choice. We rejected keeping the hints until #129 lands: the owner asked for them gone now.
  - **The kicker keeps `PRESS J OR CLICK TO KICK`, and an offense with a kick called keeps `PUNT · PRESS K TO CHANGE`.** These pills are the only place a new player learns to kick, and they show only for the player who has to act. The kick meter (#68) is meant to take them over. The return team's `GET READY TO RETURN` was narration with nothing to do, so it's gone.
  - **No `LOFT N°` readout** beside the QB crosshair. The view pitch is the loft, and the arc dots and landing reticle already show where the throw goes.
  - **The play clock only alarms on your own snap (#168).** Against bots it counts their 5 s huddle (#136), so the old "red at 5 s" rule painted it red for the whole presnap on defense. Red now means "your clock is running out".
- **The carry is a procedural arm pose, not a clip (#244).** No Quaternius clip has a football carry, and the run clips swing the hand at the hip, so the old pin (`hand_position() + basis.z * 0.08`, and `+z` is backward in Godot) left the ball inside the torso. `art/athlete_pose.gd` is a `SkeletonModifier3D`: after the clip poses the skeleton it runs two-bone IK on the right arm to a hand target on the chest (`TUCK_HAND`, elbow toward `TUCK_POLE`, both in `spine_03` space), blended by a weight `player.gd` smooths over ~0.2 s. A QB for whom `world.can_throw()` holds instead holds the ball at `HOLD_BALL` in front of the chest, each wrist beside it with palms turned in (`HOLD_HAND_BASIS`), and the ball sits there rather than in the right palm. A first version sent both hands to the chest with the ball still in the right palm, so the hands stacked on one side of it. Every clip clenches a fist, so a hand on the ball blends its finger joints 70% back toward the rig's open rest pose (`HAND_OPEN`), leaving a slight curl around the ball; a free hand keeps the clip's fist. `throw_release()` zeroes the weight so the throw clip is untouched. The ball sits in a palm socket (`BALL_SOCKET`, `hand_r` space). Two Godot 4.3 facts shaped the code: modifier results exist only during the skeleton update (read the bones at any other time and you get the plain clip pose), so the view pins the ball from `skeleton_updated` and caches the socket transform for `ball_transform()`; and a skeleton outside the tree refreshes global poses lazily, so tests call `force_update_all_bone_transforms()`. Replays don't record the holder, so the pose is off in replays. Rejected: authoring a tuck clip (needs Blender work and an `AnimationTree` with per-bone filters, and doesn't help the later head-look and reach work, #245/#246).
- **Heads track the ball within neck limits (#245).** The same `athlete_pose.gd` modifier turns `neck_01` (40%) and `Head` (60%) toward the ball view, about the chest's up and left axes, so it works on any clip and in replays (the ball view is replayed). Only athletes with a reason to watch the ball look (`player.gd` `watches_ball()`): the defense reads it (snap, carrier, pass) unless engaged in a block; offensive linemen only on a loose ball within 15 yd; other offensive players for the snap, then only a pass or loose ball within 15 yd (they're running routes or blocking while it's held); nobody engaged in a block, the carrier, or anyone down, diving or celebrating. Yaw is clamped to ±80°, and past that the look fades to neutral by 120°, so a ball behind you never wraps the neck; pitch is clamped to −30°/+40°. `player.gd` smooths the look point and weight (`LOOK_K`), so a fast ball is followed, not snapped to; a jump of more than 4 yd in one frame (new spot, replay seek) does snap, so heads don't sweep across the field. Heads only turn when the athlete is big enough on screen to see it (`head_visible()`: about 25 yd for the follow camera, further for zoomed replay cameras), which roughly halves the cost to about +40 µs/frame (`../optimization/LOG.md` perf-05, perf-06). A first pass clamped yaw at 70° and faded by 110°: a wide receiver with the ball 90° to his side before the snap barely turned (35°), so the limit went up to 80° (60° turn at 90°).

## Code and tests
- `src/game/presentation.gd`: ball, markers, effects, crowd, jumbotron
- `src/game/overlay.gd`: scorebug and HUD
- `src/game/player.gd`: athlete views
- `src/game/art/athlete_pose.gd`: procedural pose over the clip (ball carry #244, head look #245)
- `src/game/art/`: stadium, field, materials, shaders, quality presets
- `src/game/render_cache.gd`: shared low-poly meshes and materials (lint forbids default-tessellation meshes)
- `src/ui/music_player.gd`: menu soundtrack
- Tests:
  - `tests/render_budget.gd` and `tests/test_render_perf.gd` cap tris, instances, shadows, materials and skinned meshes (`./scripts/perf.sh`)
  - Visuals are verified with `./scripts/shot.sh` PNGs (`../TESTING.md`)
  - `tests/game_flow.gd` exercises the live overlay. `./scripts/visual_test.sh` checks and captures the scorebug in scrimmage, kickoff and conversion states, and `tests/visual/you_marker_test.gd` checks the ground ring (and no floating chevron) in a match, an instant replay and the training ground.
  - `tests/test_helmet_fit.gd` skins the cranium on the CPU (GLB data via `GLTFDocument`) for 66 poses across every clip the view plays plus all taunts. It asserts no vertex crosses the helmet shell, the skull stays covered and the crown and median gaps stay within 1.2 cm and 2.5 cm. `tests/visual/helmet_fit_test.gd` captures head close-ups (front, back, profile, opponent) in eight poses.
  - `tests/visual/camera_framing_test.gd` (#128) projects your ring to the screen and asserts it sits above the scorebug pre-snap on defense, every frame of a backpedal at max aim range, and at a sack's whistle; and that every offensive teammate within 8 yd of the QB is whole in the pre-snap POV. `tests/test_main_scene.gd` checks `_framed_look` across camera distances, FOVs, aim ranges and lag.
  - `tests/visual/hud_polish_test.gd` asserts the fixed scorebug width (presnap, live, whistle), the dead-ball summary, the status pill clearing the scorebug, the themed picker pinned top-right and the meters beside the bug.
  - `tests/test_athlete_pose.gd` (#244) samples the real Sprint and Idle clips: the tucked hand stays within 0.25 m of the chest (the plain sprint doesn't), a passer's hands sit on opposite sides of the ball (each 0.12–0.3 m from its center), weight 0 leaves the arm untouched, hands on the ball open (curl less than half the fist's) while a free hand stays a fist, the throw release drops the pose at once, and the palm socket sits in the hand with the ball's long axis along the forearm. `tests/game_flow.gd` frames 39 (QB pre-throw) and 7900 (RB after the handoff) check in the live scene that the pose is on and the ball sits in the palm socket in the same frame.
  - `tests/test_athlete_pose.gd` (#245) also checks the look clamp math (ahead, 45°, 90°, behind, steep up/down), that the head turns 45° toward a target 45° to the side, that across 120 directions the head never turns past the limits, and that look weight 0 leaves the head alone. `game_flow.gd` frames 39 and 7900 check that each athlete near the camera looks exactly when its role says so, far ones and the carrier don't, and with the ball held no offensive player looks (6 do with the rule forced on); a table test covers 13 role/situation cases; frame 2474 checks that after the kickoff reset every head's look point is already on the ball (49 m behind with the snap removed).
  - `tests/visual/hud_declutter_test.gd` (#131) asserts a live match shows no mode line while the Tab board does, the toss and kickoff show no phase words or toss key hints (the kicker keeps the kick hint), a bot huddle's play clock isn't red, and no `LOFT` text is drawn beside the QB crosshair.

## Open issues
- #159 Football model: prolate spheroid with laces/seams, correct spin axis (the held ball is still a 0.3 m sphere)
- #246 Catch stance and arm reach toward an incoming ball
- #247 Hold left click to reach: larger catch radius while held
- #160 Uniform quality pass: jersey/pads materials, numbers, team colors
- #173 Skinned athlete vanishes in close-ups during Hit_Knockback (culled by rest-pose AABB)
- #10 C10 Throw readability: landing marker, aim-zoom
- #12 C31 Who's who on the field: nameplates, rings, "you" marker
- #22 C16 Audio foundation + live play feed
- #31 Team voice chat (team-only, host-relayed)
- #34 C33 Team identity: names, colors, field branding, "ball on <TEAM> 19"
- #38 B06 Juice: hit-stop, screenshake, crowd stingers
- #43 C28 Commentary barks
- #44 C29 Events and variety: weather, time of day, rotating modes
- #228 POV passer camera: your own ring sits behind the scorebug
