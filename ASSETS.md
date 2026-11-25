# Third-party assets

Only CC0 / permissive assets. Never use assets, names, UI or audio from Gridiron.

| Asset | Path | Source | License | Used for |
|---|---|---|---|---|
| Universal Animation Library 1 + 2 (rigged mannequin + 86 animations, one 65-bone skeleton) | `assets/characters/UAL{1,2}_Standard.glb` | Quaternius (quaternius.itch.io/universal-animation-library, -2) | CC0 1.0 (`assets/characters/LICENSE_Quaternius_UAL.txt`) | Athlete bodies + animations (uniform colors are baked per bone region at runtime) |
| American football player, ready (helmet, facemask and chin strap) | `assets/characters/InnersceneHelmet.glb` | [Innerscene, adapted from MakeHuman](https://www.innerscene.com/tools/library/3d-parts/american-football-player-ready-3d-person-team-sports-aad6f516) | CC0 1.0 | Local team's helmet, resized and fitted with a customizable crown stripe |
| Moon 01 (regolith) | `assets/textures/regolith/` | Poly Haven (polyhaven.com/a/moon_01) | CC0 | Ground outside the stadium |
| Concrete034 | `assets/textures/concrete/` | ambientCG | CC0 | Stadium concrete |
| Metal009 | `assets/textures/metal/` | ambientCG | CC0 | Light towers / trusses |
| Grass004 | `assets/textures/grass/` | ambientCG | CC0 | Turf detail |
| Space skybox (galaxy) | `assets/sky/` | Kenney (Skyboxes Space) | CC0 (`assets/sky/LICENSE_Kenney.txt`) | Night sky panorama |
| Oswald (variable) | `assets/fonts/Oswald.ttf` | Google Fonts (github.com/google/fonts) | SIL OFL 1.1 (`assets/fonts/OFL.txt`) | Menu/brand type, jersey + yard numbers |
| Rajdhani Bold | `assets/fonts/Rajdhani-Bold.ttf` | Google Fonts (github.com/google/fonts) | SIL OFL 1.1 (`assets/fonts/rajdhani_OFL.txt`) | HUD headings |

Original (made in this repo): stadium bowl/crowd/towers/arches/jumbotron geometry, turf/sky/ribbon/emblem shaders, helmet + facemask + pads, football, overlay.

The opponent uniform is an original skinned model with its own padded jersey,
gloves, pants, cleats, helmet and cage. Open `tools/characters/OpponentUniform.blend`
in Blender to edit the authored asset. Export a Y-up GLB with skinning enabled
and animations disabled to `assets/characters/OpponentUniform.glb`. Keep the
existing bone and material names for in-game animation and cosmetics.
`tools/characters/build_uniforms.py` rebuilds both GLBs from the original
geometry recipe and the Innerscene download. The local team uses the rigged
Quaternius body with the imported helmet and cage.
