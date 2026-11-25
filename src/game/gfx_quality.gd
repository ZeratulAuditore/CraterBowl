extends RefCounted
## Graphics quality presets. One place that decides what the GPU is asked to do.
## A settings menu should call `apply()` with the player's choice; main.gd applies
## `auto_level()` at startup (or `--quality=low|medium|high` from the command line).
##
## See docs/optimization/README.md ("Rendering budget") for why each knob exists.

enum Level { LOW, MEDIUM, HIGH }

const NAMES := ["low", "medium", "high"]

static func parse(s: String, fallback: Level = Level.MEDIUM) -> Level:
	var i := NAMES.find(s.to_lower())
	return fallback if i < 0 else i as Level

## Software rasterizers (llvmpipe/lavapipe/SwiftShader) run every pixel on the CPU:
## shadows there cost more than the whole rest of the frame.
static func is_software_renderer() -> bool:
	var a := RenderingServer.get_video_adapter_name().to_lower()
	return a.contains("llvmpipe") or a.contains("lavapipe") or a.contains("swiftshader") or a.contains("software")

static func auto_level() -> Level:
	return Level.LOW if is_software_renderer() else Level.MEDIUM

## sun: the scene's DirectionalLight3D (may be null). viewport: the root viewport.
static func apply(level: Level, sun: DirectionalLight3D, viewport: Viewport) -> void:
	if sun:
		sun.shadow_enabled = level != Level.LOW
		# Players are the only shadow casters; the camera never sees past ~60 yd.
		sun.directional_shadow_max_distance = 60.0 if level == Level.MEDIUM else 90.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if level == Level.HIGH \
			else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	if viewport:
		viewport.msaa_3d = Viewport.MSAA_2X if level == Level.HIGH else Viewport.MSAA_DISABLED
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if level == Level.MEDIUM else Viewport.SCREEN_SPACE_AA_DISABLED
