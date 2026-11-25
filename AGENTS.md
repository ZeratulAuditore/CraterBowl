# Fourth & Long: agent notes

Godot 4.3 football game. Work procedure: `LOOP.md`. Plan/backlog: `PLAN.md`, `FEATURES.md`, `ITERATIONS.md`.

## Testing: never open a game window
Don't run `godot --path .` or `godot -e` to check your work. In WSL it pops a real window on the
user's desktop. Everything below runs offscreen and parallel-safe. Full guide: `docs/TESTING.md`.

- `./scripts/test.sh`: headless unit tests (`tests/test_*.gd`)
- `./scripts/smoke.sh`: headless boot + scripted gameplay (`tests/game_flow.gd`) + net + matchmaking
- `./scripts/shot.sh --frames=60,200 --snap=100`: real-renderer screenshots via Xvfb + software GL.
  Supports `--press=F:KEY`, `--do=F:ACTION`, `--every=N`, and any main.gd arg. **View the PNGs.**

`--headless` draws no pixels. For anything visual, use shot.sh.
