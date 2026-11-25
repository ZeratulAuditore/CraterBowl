# 032: Play replays (B04a)

## Goal
Make replays of plays something players actually see and use: big plays replay themselves, every
replay explains what happened, and you can scrub, step and re-angle any play from the match.

## Before
A25 (iter 026) recorded every match and V replayed the last play at 0.5x. The camera stayed on your
own athlete, labels read "Play 4 - tackle", the in-match replay had no controls, and the broadcast
overlay (A26) hid the text HUD, so nothing on screen said a replay was playing.

## Options
1. **Replay a fixed window (last N seconds) on every whistle.** Simple, but routine plays get
   repetitive fast and you skip the replays.
2. **Tag plays from sim events and only auto-replay highlights** (picked). The recorder already
   hears every world event, so it can classify plays (TD, interception, fumble lost, sack, 20+ yd)
   while it records. That needs no sim change and also works on saved files.
3. **Director AI choosing cuts per frame.** Better TV feel, but a lot of tuning. It belongs in the
   B04b free-cam theater.

## Design
- `src/sim/replay.gd` (pure): each play records its LOS, offense, QB and the line it ended on (snap context).
  Events add tags. Summary text: "pass for 31 yd", "TOUCHDOWN: run for 75 yd", "SACK: loss of 7",
  "INTERCEPTION: change of possession", "pass incomplete". Highlights are tagged plays plus
  plays of 20 yards or more. Player API: `clip_play(i, speed, highlight)` (a highlight runs at 1x, then
  the last 2 s at 0.35x), `start_reel` / `next_in_reel`, `next_highlight`, `step_frames`, `progress`.
  Files from before this change still load (`.get()` defaults). The save version is now 2.
- `main.gd`:
  - **Auto highlight (offline only):** 1 s after the whistle on a highlight play, it replays once
    (`--auto-replay=0` turns it off). Online, the match keeps running, so it stays manual (V).
  - **Transport (in-match and in the viewer):** V or Enter leaves, Space pauses, `,` and `.` step a
    frame, Left/Right go to the previous/next play, H jumps to the next highlight, `[ ]` changes
    speed, C changes the camera.
  - **Cameras:** Broadcast (zoomed, near sideline, tracks the ball), End zone, Sky, and Player
    (the old follow cam). The camera cuts into a replay and on each camera change, then tracks smoothly.
  - **At FINAL, V plays the highlight reel:** every highlight in order.
- `src/game/replay_overlay.gd`: a broadcast REPLAY / HIGHLIGHT / HIGHLIGHT REEL bug with a
  blinking dot, the speed (or SLOW-MO / PAUSED), the camera name, the play summary, a
  context line (play #, clock, down and distance, highlight count), a progress bar and key hints. It
  hides the live-only match-overlay widgets during the replay and restores them afterwards (the
  scorebug stays up).

## Better than Gridiron
Gridiron never shipped replays. Here every big play replays itself with a slow-mo finish and a
label saying what happened, and the end of the match gives you a highlight reel without opening a menu.

## Acceptance criteria
- Play summaries: the yards come from the line of scrimmage (TD yards stop at the goal line). Pass/run
  kind, TOUCHDOWN / INTERCEPTION / SACK tags, and a highlight flag, which is false on short gains.
- `highlights()` lists only tagged and 20+ yd plays. `next_highlight` wraps around.
- A highlight clip slows down for its last 60 frames. The reel plays its clips in order and then ends.
- Frame-step clamps to the clip. `progress()` runs 0..1. Old files have no highlights.
- Flow (real keys): a TD is not replayed before the delay, replays itself after it, and shows the
  HIGHLIGHT overlay and the summary. The sim stays frozen. C changes the camera and the camera reaches the pose.
  `.` and `,` step frames while paused, Space resumes, and Enter skips. A skipped play never
  auto-replays again. The live widgets come back. V at FINAL plays the reel, and V exits it.
