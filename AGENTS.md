# Fourth & Long: agent notes

Godot 4.3 football game. Work procedure: `LOOP.md`. Plan/backlog: `PLAN.md`, `FEATURES.md`, `ITERATIONS.md`.

## Committing: commit everything, by default
When you finish a task (or a loop iteration), commit **everything** in the working tree without
asking: `git add -A && git commit`. That includes files other parallel sessions changed. The owner
wants the tree clean and every change in history rather than work-in-progress left lying around.
- Commit to the current branch (normally `main`). Don't push or publish unless asked.
- Never `git stash`, reset or checkout files to isolate your changes. Other sessions share this
  worktree and that discards or tangles their work.
- Write the message about your change, and add a line listing other sessions' files that rode
  along (`Also includes in-progress work: src/net/..., ...`). Check `git show --stat` afterwards.
- Never commit secrets (`.env`, keys, credentials). `.gitignore` covers build output and `user://` data.

## Testing: never open a game window
Don't run `godot --path .` or `godot -e` to check your work. In WSL it pops a real window on the
user's desktop. Everything below runs offscreen and parallel-safe. Full guide: `docs/TESTING.md`.

- `./scripts/test.sh`: headless unit tests (`tests/test_*.gd`)
- `./scripts/smoke.sh`: headless boot + scripted gameplay (`tests/game_flow.gd`) + net + matchmaking
- `./scripts/shot.sh --frames=60,200 --snap=100`: real-renderer screenshots via Xvfb + software GL.
  Supports `--press=F:KEY`, `--do=F:ACTION`, `--every=N`, and any main.gd arg. **View the PNGs.**

`--headless` draws no pixels. For anything visual, use shot.sh.
