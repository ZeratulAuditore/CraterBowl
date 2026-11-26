# Crater Bowl: out-of-game experience

This covers everything outside a match: name, brand, menus, settings, finding games, internet play and distribution.
Feature-level doc: how this works **today** on `main`. The in-match game is in the other `docs/features/` docs, the vision in `../vision.md`. Networking internals: `../design/netcode.md`. Open work: GitHub issues labelled `area:ui`, `area:infra` and `area:accessibility` (listed below).

## Identity
- **Name: Crater Bowl.** The stadium is built inside a lunar crater, which matches the graphics pass (lunar dome stadium, HELIOS vs NEBULA).
  No video game with this name was found (2026-11-25 search). The low-gravity football space is crowded (Gridiron's Chaosball, G-Ball, Zero-G), so the name leans on *crater/bowl*, not *gravity*.
- **Mark:** a gold football launching out of a cyan-rimmed crater. Wordmark: "CRATER" in cream + "BOWL" in cyan, set in Oswald Bold (OFL), converted to paths.
  - Sources: `tools/brand/build_logo.py` → `assets/brand/*.svg`; `tools/brand/rasterize.gd` → PNGs (icon 64/256/512, wide and stacked logos).
  - Palette (shared with art direction): space `#07080F`, navy `#0E1424`, cream `#FFF4E0`, cyan `#5CE1FF`, orange `#FF6A1F`, gold `#F2BF26`. Constants are in `src/ui/ui_theme.gd`.
- **User data** lives in a fixed dir, `crater-bowl` (`config/use_custom_user_dir`), so a future rename can't orphan profiles. On first windowed launch, `Launch.migrate()` copies data from the old `Fourth & Long` dir. It never overwrites, skips `test_*`, and runs once (`.migrated` marker).

## Architecture (how the menu drives the game)
- `scenes/menu.tscn` is the main scene. It forwards straight to `main.tscn` when headless or when any CLI flag is given, so tests, dedicated hosts and the matchmaker behave exactly as before.
- **Autoload `Launch`** (`src/ui/launch.gd`):
  - `start_game(opts)` stores options that `main._cli_args()` merges in. **A menu choice is the same thing as a CLI launch** (`{"host": true}` == `--host`), so every menu path runs code the test suite already covers.
  - Owns the in-match **Esc overlay** (resume / controls / leave match / quit). Offline play pauses; online play keeps running.
  - **Rebinding and gamepad** work as a translation layer: the player's key, or a gamepad button/stick/trigger, is re-injected as the default key that `main.gd` reads (`src/ui/controls.gd`). Match code never needs to know about bindings.
- Settings live in `user://settings.cfg` (`src/ui/settings_store.gd`): name, fullscreen, vsync, 3D resolution, frame cap, master volume, matchmaker address, UPnP, key bindings. Headless runs ignore the player's file.

## Menu map
| Screen | What it does |
|---|---|
| Welcome (first run) | Pick a name (2–16 chars, not You/Bot/Host) |
| Play online | Rules (classic/Chaosball) + size + party, Quick match / Ranked, host a match (optionally listed publicly), join by invite code/IP, live browser of open matches |
| Play vs bots | Offline full match, any size/rules |
| Practice | Passing / catching / tackling / scrimmage drills |
| Locker | Level/XP, equip unlocked cosmetics + number |
| Leaderboards | Ranked rating + per-position career tables |
| Replays | Saved match replays, newest first |
| Settings | Player, video, audio, online, controls (click to rebind; conflicts swap) |

## Finding games + internet play
- **Matchmaker** (`--matchmaker`) does queues (casual/competitive, parties, Chaosball) and now also the **server browser**: hosts `register` their lobby every 5 s (`src/net/lobby_advertiser.gd`); entries expire after 20 s (`src/net/lobby_registry.gd`). `whoami` returns the caller's public IP.
- **UPnP** (`src/net/port_mapper.gd`): before hosting or queueing, the menu asks the router to forward the UDP port (24565 for hosting, 24566 for queue hosts). It puts the router's **public IP in the invite code**, so friends on other networks can join without manual port forwarding. If UPnP fails, or the connection is behind carrier-grade NAT, the code falls back to the LAN address and the menu says what to forward.

## Distribution
- `./scripts/export.sh [Linux|Windows|macOS]` builds `build/dist/CraterBowl-<VERSION>-{windows,linux,macos}.zip` (~30/24/50 MB). It syncs `VERSION` into `project.godot` + presets, then boot-checks the exported Linux binary (headless practice drill, version line).
  - Needs Godot 4.3 export templates in `~/.local/share/godot/export_templates/4.3.stable/`, from the official `Godot_v4.3-stable_export_templates.tpz` release asset.
- Version: bump `VERSION` (semver). The menu shows it, and the game prints `Crater Bowl vX (OS)` at startup for bug reports.
- `deploy/README-player.txt` ships inside each zip (how to host/join, ports, controls, data location).
- **Matchmaker hosting:** `deploy/Dockerfile.matchmaker` (Docker) or `deploy/crater-bowl-mm.service` (systemd). Either runs the exported Linux binary with `--headless -- --matchmaker --port=24600` on UDP 24600.
- **itch.io:** `ITCH_TARGET=<user>/crater-bowl ./scripts/publish_itch.sh` pushes all three zips with butler (channels windows/linux/macos). It never runs implicitly.

### Store copy (draft)
> **Crater Bowl.** Arcade football under a dome on the Moon. 3v3 to 7v7 online with friends, bots in every empty slot, precision passing, live play calling and routes, plus Chaosball: low gravity, anyone can throw, walls are in play, and pass streaks raise your touchdown value. Quick match, ranked seasons, private lobbies with invite codes, practice drills, replays and earnable cosmetics with no pay-to-win.

## Open issues
Open owner decisions and known gaps moved to GitHub issues on 2026-11-25 (#1):
- #48 Decide: host the public matchmaker (VPS/AWS + DNS)?
- #49 Decide: storefront (itch.io first vs Steam)
- #50 Decide: code signing / notarization
- #32 B07 NAT relay for CGNAT/strict routers + hosted public matchmaker
- #33 Gamepad: right-stick aiming
- #46 Windows exe icon (rcedit)
- #47 UPnP failure notice appears after the match instead of in the lobby
- #24 C18 Guided tutorial
- #25 C19 Accessibility & camera options
- #22 C16 Audio foundation + live play feed (no in-match audio yet; the menu soundtrack exists)
