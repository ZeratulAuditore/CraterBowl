# Optimization log

Newest first. Every perf change gets an entry with **before/after numbers from the same machine
and mode** (protocol: `README.md` §5). Write down what didn't work too.

Machine for all entries so far: WSL2 Ubuntu 24.04, i7-11800H (16 threads), RTX 3080 Laptop GPU, Godot 4.3.
"CPU" = Xvfb + Mesa llvmpipe; "GPU" = Xvfb + Mesa d3d12 → RTX 3080 (Compatibility renderer).

---

## 2026-11-25 — perf-01: render pass, interpolation, gates (branch `perf-optimization`)

Trigger: the user said the game "feels low quality in terms of performance". The windowed game
process sat at about 490% CPU: it was rendering on **llvmpipe** (Vulkan in WSL has no GPU driver).

### Phase 1 (primitive-mesh art, before the rigged athletes landed)
Diagnosis: Godot's default primitive meshes (SphereMesh 64x32 ≈ 4k tris) for 14 athletes plus
24 arc dots plus ball plus reticle, a separate material per mesh, every field box casting
shadows, and 4 shadow splits came to about **590k triangles, about 425 draw calls** for a scene
of capsules.

| Mode | FPS before → after | p99 frame | draws | triangles |
|---|---|---|---|---|
| CPU llvmpipe, GL compat | 4.7 → **32.7** | 457 → 152 ms | 425 → 121 | 592k → 7.7k |
| GPU d3d12, GL compat | 34.2 → **61.2** | 116 → 38 ms | 422 → 156 | 592k → 14.5k |
| CPU llvmpipe, Vulkan Forward+ | 5.3 → 23.2 | 298 → 126 ms | 507 → 157 | 592k → 7.7k |

Changes: `render_cache.gd` (shared low-poly meshes and materials), field boxes batched into one mesh
per color with no shadows, throw arc as one MultiMesh, unshaded markers and reticle with no shadows,
route art rebuilt only on change, render interpolation for athletes and ball, exp-smoothed camera.

### Phase 2 (after merging the CC0 rigged-athlete graphics overhaul)
The new art brought the cost back: **origin/main measured 9.9 fps GPU, 5.0 fps CPU,
1.23M rendered triangles, 737 draws**.

Category bisect (GPU path, `--gfx=low`, `render_bench.sh --exp=...`):

| Hidden | render CPU ms/frame | FPS |
|---|---|---|
| nothing | 127 | 6.4 |
| **skinned athlete bodies** | **16** | **32.8** |
| gear / labels / crowd / stadium / paused anim | within noise of baseline | |

3v3 (6 skinned) measured 38 ms against 127 ms for 7v7 (14): skinning costs **about 8–9 ms per
athlete** on Compatibility + d3d12, linear. Pausing AnimationPlayers doesn't help; it's the
skinning (transform feedback, emulated by Mesa d3d12), not animation playback. Native Vulkan
skins with compute shaders and should not have this cost. **Still to verify on the user's
Windows build.**

Fixes applied on top of the new art:
- Helmet, pads and visor: default `SphereMesh.new()` (4k tris each, x3 per athlete) → `RC.sphere`
  (12x6; helmet 20x12). Triangles in the scene: 1.23M → 816k rendered (GPU, gfx=high).
- Gear, numbers, collar and stripe don't cast shadows: shadow casters 162 → 92.
- Overlay HUD text refresh 60 Hz → 20 Hz; skip unchanged shader params (crowd excitement,
  ring color); skip the trail re-upload when empty. Presentation CPU about 1.6 ms → about 0.4 ms
  per frame (headless, noisy, load 9–13).
- Render interpolation re-applied to the new `player.gd` (`place`/`interpolate`). Its animation
  picker derives speed from position deltas, so it now sees smooth per-frame motion.

| Mode (gfx auto) | origin/main | perf branch |
|---|---|---|
| GPU d3d12 FPS / p99 frame | 9.9 / 520 ms | 11.4 / **117 ms** |
| CPU llvmpipe FPS | 5.0 | 4.8 (pixel-bound) |
| Headless scene tick p50 (3 runs, load ≈10) | 4.0–4.9 ms | 3.35–4.2 ms |

Takeaway: on this WSL box the rigged athletes are skinning-bound and nothing else matters
until that's solved. Options, in order: (1) measure the native Windows build; if it's fine,
WSL is just a bad test bed. (2) A lower-vertex athlete mesh for `--gfx=low`. (3) Skin at
reduced rate for off-screen or far athletes.

### Gates added
`scripts/check.sh` (lint + unit + perf + smoke), `scripts/perf.sh` (render budget plus CPU
medians), `scripts/lint.sh` (every script compiles; perf rules), `tests/test_determinism.gd`,
`tests/test_render_perf.gd`, `tests/render_budget.gd`, and the pre-commit hook
(`scripts/install-hooks.sh`). Mutation-tested: restoring 64-segment spheres makes the render
budget fail (85k > 20k on the old art).

### Didn't work / don't repeat
- `Performance.get_monitor(TIME_PROCESS/TIME_PHYSICS_PROCESS)` per frame: these are about 1 s
  averages, so per-frame spike hunting with them is meaningless. Use wall time between frames under
  `--fixed-fps 60` headless.
- Mean-based CPU gates flaked at load 5–13 (scene "8.7 ms" vs 1.0 ms idle). Use medians.
