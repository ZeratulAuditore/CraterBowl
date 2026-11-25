# Testing Fourth & Long without opening the game

**Never launch a windowed game (`godot --path .`, `godot -e`) to check your work.** In WSL it opens a
real window on the user's desktop, and several sessions doing it at once is disruptive. Use the tools
below instead. Every check here runs offscreen and in parallel with other sessions.

| What you want to know | Command | Time |
|---|---|---|
| Rules/sim logic is right | `./scripts/test.sh` | ~10s |
| Scene boots clean + scripted play works | `./scripts/smoke.sh` (also runs net + mm) | ~2–3 min |
| Networked behavior | `./scripts/net_test.sh`, `./scripts/mm_test.sh` | ~15s each |
| **What it looks like** (visuals, HUD, camera, art) | `./scripts/shot.sh ...` then view the PNGs | ~30s |

## Two ways to run Godot offscreen

1. **`--headless`** (test.sh, smoke.sh, net/mm tests). Dummy renderer and dummy audio, no display.
   Fast, but **it draws no pixels**: `get_viewport().get_texture().get_image()` comes back empty.
   Use it for logic, scene flow and anything you can assert in code. The `mesh_storage.h` /
   `Parameter "m" is null` errors are known dummy-renderer noise (allowlisted in smoke.sh).
2. **Xvfb + Mesa software GL** (`scripts/shot.sh`). Real Compatibility (OpenGL 3) renderer on
   `llvmpipe` (CPU) inside a private virtual X display. You get real lighting, shadows, materials
   and HUD, and nothing appears on screen. It is slower (~6–7 fps), so capture a few frames rather
   than playing whole drives. Needs `xvfb-run` (`sudo apt install xvfb`; already installed here).

`--write-movie` and other in-engine capture need a real renderer too, so they also need mode 2.

## Screenshots: `scripts/shot.sh`

```bash
./scripts/shot.sh --frames=60,200 --snap=100            # pre-snap and mid-play
./scripts/shot.sh --frames=160 --press=40:Tab --snap=100  # switch position, then snap
./scripts/shot.sh --every=30 --snap=60 --frames=300     # strip of frames: 30, 60, ... 300
./scripts/shot.sh --frames=30 --size=5 --practice=routes  # any other arg goes to main.gd
./scripts/shot.sh --out=/tmp/hud/before --frames=30     # choose the output prefix
```

It prints `SHOT <absolute path> (OK)` per image. **Open the PNGs with your Read/image tool and
look at them.** A file existing is not a visual check. Compare before/after shots for visual changes.

Flags (all optional; implemented in `tools/capture.gd`):

| Flag | Effect |
|---|---|
| `--frames=F1,F2` | capture at these physics frames (60 = 1s). Default 120 |
| `--every=N` | also capture every N frames |
| `--snap=F` | snap the ball at frame F |
| `--do=F:ACTION,...` | `main.do_action({"a": ACTION})`, e.g. `snap`, `tackle`, `throw`, `cycle`, `team` |
| `--press=F:KEY[:HOLD],...` | real key event through `Input.parse_input_event` (so `_unhandled_key_input` and `Input.is_key_pressed` both see it), held HOLD frames (default 1). Key names: `Space`, `Tab`, `V`, `W`, `Shift`, `Enter`... |
| `--call=F:METHOD,...` | `main.call(METHOD)`, e.g. `next_play` |
| `--out=PREFIX` | writes `PREFIX_0060.png`. Default `$CLAUDE_JOB_DIR/tmp/shots/shot`, else `/tmp/fourth-and-long-shots/shot` |

Env: `RES=1920x1080` (default 1280x720), `TIMEOUT=240`, `GODOT=/path/to/godot`.

Notes:
- Frames run at `--fixed-fps 60`, so frame N is the same game moment as frame N in
  `tests/game_flow.gd`. Shots are deterministic up to AI randomness.
- shot.sh passes `test_shot_*` profile/leaderboard/ranked/replay paths unless you override them,
  so screenshots never touch the player's real save data.
- `xvfb-run -a` picks a free display, so parallel sessions don't collide.
- llvmpipe is a software rasterizer. Use it to check *what is drawn*, not frame rate or GPU-only
  effects. Perf numbers have to come from the user's real GPU, so ask them.
- Don't put screenshots in the repo. Write them to the job tmp dir; if one belongs in an iteration
  doc, describe it in words.

## Driving gameplay from scripts

For anything you can assert (positions, phase, HUD text, whistle reason), extend
`tests/game_flow.gd` rather than eyeballing screenshots. It runs headless in smoke.sh. Use shot.sh
when the question is visual: does it look right, is it visible, is the camera framing it, is the HUD
legible, does the new art read.

Input rule (from LOOP.md): player-facing input must be exercised through the real key handler.
In game_flow that's `_key()`; in shot.sh that's `--press`.

## When the user has to look

Only for things software rendering can't show: real-GPU frame rate, feel and timing, audio. In
that case say exactly what to run (`godot --path .`) and what to look for. Don't launch it yourself.
