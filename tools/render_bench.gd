extends SceneTree
## Real-renderer benchmark: frame time + draw calls + triangles for the main scene.
## Run via scripts/render_bench.sh (offscreen Xvfb; never opens a desktop window).
## Plays are snapped automatically so LIVE action is measured, not just presnap.
## Prints `RBENCH key=value` lines. Args: --frames=N (default 300), plus any main.gd arg.

var _main: Node
var _f := 0
var _frames := 300
var _dts: Array = []
var _last := 0
var _draws := 0
var _prims := 0
var _objs := 0
var _cpu_ms: Array = []   # render thread CPU (culling, draw submission)
var _gpu_ms: Array = []   # GPU time for the viewport
var _scr_ms: Array = []   # script + animation + physics (process/physics monitors)

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			_frames = int(a.split("=")[1])
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	process_frame.connect(_tick)

func _tick() -> void:
	_f += 1
	var now := Time.get_ticks_usec()
	if _f > 60:   # warm-up: shader compiles, first uploads
		_dts.append(now - _last)
		_draws = maxi(_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		_prims = maxi(_prims, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		_objs = maxi(_objs, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		var vp := root.get_viewport_rid()
		_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu())
		_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
	_last = now
	if _f == 20:
		_apply_experiment()
	if _main.world.phase == _main.World.Phase.PRESNAP and _f % 120 == 0:
		_main.world.snap()
	if _f >= _frames + 60:
		var s := _dts.duplicate()
		s.sort()
		var sum := 0
		for d in s:
			sum += d
		print("RBENCH adapter=%s" % RenderingServer.get_video_adapter_name())
		print("RBENCH fps=%.1f" % (1e6 * s.size() / sum))
		print("RBENCH frame_ms_p50=%.2f" % (s[s.size() / 2] / 1000.0))
		print("RBENCH frame_ms_p99=%.2f" % (s[int(s.size() * 0.99)] / 1000.0))
		print("RBENCH frame_ms_max=%.2f" % (s[-1] / 1000.0))
		print("RBENCH render_cpu_ms_p50=%.2f" % _median(_cpu_ms))
		print("RBENCH render_gpu_ms_p50=%.2f" % _median(_gpu_ms))
		print("RBENCH script_ms_p50=%.2f" % ((Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0))
		print("RBENCH draw_calls_max=%d" % _draws)
		print("RBENCH triangles_max=%d" % _prims)
		print("RBENCH objects_max=%d" % _objs)
		quit()

func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return s[s.size() / 2]

## --exp=a,b: hide a category to measure what it costs (diagnosis only; see docs/optimization).
##   chars (skinned bodies), gear (helmets/pads/masks), labels (Label3D), crowd, stadium, anim (pause AnimationPlayers)
func _apply_experiment() -> void:
	var exp := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--exp="):
			exp = a.get_slice("=", 1)
	if exp == "":
		return
	var parts := exp.split(",")
	for n in _walk(_main):
		var path := str(n.get_path())
		if "chars" in parts and n is MeshInstance3D and n.get_parent() is Skeleton3D:
			n.visible = false
		if "gear" in parts and n is MeshInstance3D and "Athlete" in path and not (n.get_parent() is Skeleton3D) and n.name != "BlobShadow":
			n.visible = false
		if "labels" in parts and n is Label3D:
			n.visible = false
		if "crowd" in parts and n is MultiMeshInstance3D and "Crowd" in str(n.name):
			n.visible = false
		if "stadium" in parts and n.name == "Stadium":
			n.visible = false
		if "anim" in parts and n is AnimationPlayer:
			n.pause()
	print("RBENCH experiment=%s" % exp)

func _walk(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out
