# Replays

Feature-level doc: how this works for players **today** on `main`. Open work: GitHub issues labelled `area:replays` (listed below).

## Summary
Every match is recorded. At any dead ball you can press V to watch the last play again at half speed, and
when a match ends the whole recording is saved to disk. Saved replays open in a viewer from the main menu,
the post-game overview or the command line. There are no highlight clips or free camera yet.

## How it plays

### Instant replay (in match)
| Input | Effect |
|---|---|
| V (gamepad Back) | outside a live play: replay the last completed play at 0.5×; V again exits early |

- Rejected during a live play or before any play has finished.
- The HUD shows `REPLAY 0.5x  Play N - <how it ended>  [V exit]`. The clip returns to the live view when it ends.
- Offline, the match is paused while you watch (clock and next-play delay stop).
  Online, the host's match keeps running underneath; your own input isn't sent while the replay shows.
- Practice drills record too, but they never save a file.

### Saved replays and the viewer
- At FINAL the match host (or offline player) saves `user://replays/<timestamp>.replay` and prints `REPLAY saved: <path>`.
  `--replay-dir=DIR` overrides the folder.
- Open one from **Main menu → Replays** (newest first; test files skipped), the **Watch replay** button in the
  post-game overview, or `-- --replay=FILE`.
- The viewer rebuilds the match size and mode from the file and plays from the start at 1×.

| Viewer key | Effect |
|---|---|
| Space | pause / resume |
| Left / Right | jump to the previous / next play's start |
| [ / ] | halve / double speed (0.25× to 2×) |
| V | stop playback (the scene left behind is the fresh match the viewer built, which then starts playing) |

### What is recorded
- 30 frames per second (`Replay.FRAME_EVERY` = every 2nd 60 Hz tick): phase, ball x/y/z, and each athlete's
  x/y plus diving/grounded flags. Facing, score and HUD state are not recorded.
- Plays: a snap opens a play; tackle, out of bounds, touchdown, incomplete or explosion closes it, and the label
  gets that result ("Play 4 - touchdown").
- File: zstd-compressed Godot `store_var` of `{version: 1, meta: {size, mode}, plays, frames}`; loading never decodes objects.
  A 2-minute bot match was about 170 KB (iteration 026).

## Design decisions
- Playback is view-only: views read interpolated replay frames, and the sim is never rewound, so replay can't desync a match.
- Compact float frames instead of full snapshots keep files small enough to save every match automatically.
- Instant replay is one key at every dead ball, with no menu, to beat Gridiron's lack of replays.
- Iteration 026 lists team names in the file meta; the code saves only size and mode.

## Code and tests
- `src/sim/replay.gd` — recorder, play bracketing, playback (time, speed, seek, interpolation), save/load.
- `src/game/main.gd` — `toggle_replay`, `open_replay`, `_save_replay`, `_render_replay`, viewer keys, replay HUD line.
- `src/ui/main_menu.gd` — Replays screen (`list_replays`) and the post-game "Watch replay" button.
- `src/ui/controls.gd` — V / gamepad Back binding and viewer help line.
- Tests: `tests/test_replay.gd` (capture rate, play bracketing, interpolation/seek/speed, save/load size),
  `tests/game_flow.gd` (real V key, sim frozen, save at final, viewer), `tests/test_out_of_game.gd` (replay listing).

## History
- 026 [Replays](../iterations/026-replays.md)

## Open issues
- #36 B04 Instant replay + highlight clips (remaining scope after B04a)
