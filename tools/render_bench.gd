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

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			_frames = int(a.split("=")[1])
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	process_frame.connect(_tick)

func _tick() -> void:
	_f += 1
	var now := Time.get_ticks_usec()
	if _f > 60:   # warm-up: shader compiles, first uploads
		_dts.append(now - _last)
		_draws = maxi(_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		_prims = maxi(_prims, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		_objs = maxi(_objs, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
	_last = now
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
		print("RBENCH draw_calls_max=%d" % _draws)
		print("RBENCH triangles_max=%d" % _prims)
		print("RBENCH objects_max=%d" % _objs)
		quit()
