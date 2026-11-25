extends SceneTree
## Render the main scene with a real GPU and save screenshots.
## godot --path . -s res://tools/shot.gd -- --out=/tmp/x --frames=90,240 [--snap=120] [main args...]
var main
var frames: Array = []
var out := "user://shot"
var snap_at := -1
var f := 0
var t0 := 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
		elif a.begins_with("--frames="):
			for s in a.substr(9).split(","): frames.append(int(s))
		elif a.begins_with("--snap="): snap_at = int(a.substr(7))
	if frames.is_empty(): frames = [120]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _process(_d: float) -> bool:
	f += 1
	if f == 30:
		t0 = Time.get_ticks_usec()
	if f == frames.max():
		print("PERF draws %d prims %d objects %d" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])
		print("PERF avg frame %.1f ms over %d frames" % [(Time.get_ticks_usec() - t0) / 1000.0 / (f - 30), f - 30])
	if f == snap_at:
		main.do_action({"a": "snap"})
	if f in frames:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("%s_%04d.png" % [out, f])
		print("SHOT %s_%04d.png" % [out, f])
	return f >= frames.max() + 1
