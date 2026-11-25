# 026: Replays (A25)

## Goal
Record matches and play them back: an instant replay of the last play in game, and saved full-match replays you can scrub.

## How Gridiron does it
Replays were a promised full-release feature ("replays, more character customization…").

## Design
- `src/sim/replay.gd` (pure):
  - **Recorder:** `capture(world)` every physics tick and keep every 2nd (30 Hz). Each frame is a PackedFloat32Array: phase, ball xyz, then per athlete x, y, flags (1 = diving, 2 = grounded). About 50 floats per 7v7 frame, so a 10-min match is roughly 4 MB raw and much less compressed.
  - **Plays:** `snap` opens a play; tackle/OOB/TD/incomplete/explode closes it. A play is {start, end, label}.
  - **Player:** `time` in frames (fractional), `speed` (0.25–2×), `advance(dt)`, `sample()` interpolates positions between frames, `seek_play(i)`, `ended()`.
  - Save/load with `FileAccess.open_compressed` + var_to_bytes (no objects decoded). Meta: size, mode, team names.
- Main:
  - Every match records. **V** at a dead ball plays an **instant replay of the last play at 0.5×**: views read replay frames (the sim is untouched; offline, the sim and auto-advance pause while you watch). V again or the end of the clip returns to live.
  - At FINAL the replay saves to `user://replays/<timestamp>.replay` (`--replay-dir` override).
  - `-- --replay=FILE` opens a viewer: Space pause, ←/→ previous/next play, [ / ] speed.

## Better than Gridiron
Instant replay at every dead ball, with no menu diving. Replays are tiny and deterministic.

## Acceptance criteria
- 60 Hz sim → 30 Hz frames; frame contents match world state at capture.
- Plays bracketed snap → whistle with labels.
- Player interpolates halfway between frames; seek_play jumps to a play's start; speed scales advance; clamps at the end.
- Save/load round-trip equal; a 2-min bot match is < 1 MB on disk.
- Flow: play → dead → real V key → replay active, views at recorded positions, sim frozen (offline) → ends → live; final saves a replay file (temp dir); the viewer loads it.
