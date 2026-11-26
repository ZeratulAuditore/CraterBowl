extends SceneTree
## Diagnosis: per-tick CPU with one subsystem switched off, to see what it costs.
##   godot --headless --fixed-fps 60 --path . -s res://tools/cpu_breakdown.gd -- --exp=anim
## --exp = none | anim (AnimationPlayers) | views (athlete _process) | pres (Presentation)
##         | skel (Skeleton3D) | stadium. Compare against --exp=none, interleaved, 3 runs each:
## timings swing 2x with machine load (see docs/optimization/README.md "Measuring under load").
var m; var f := 0; var last := 0; var dts := []; var exp := ""
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--exp="): exp = a.get_slice("=", 1)
	m = load("res://scenes/main.tscn").instantiate(); root.add_child(m)
	process_frame.connect(func():
		f += 1
		if f == 10: _apply()
		var now := Time.get_ticks_usec()
		if f > 40: dts.append(now - last)
		last = now
		if m.world.phase == 0 and f % 90 == 0: m.world.snap()
		if f > 640:
			dts.sort(); print("EXP %-12s p50=%5d us  p99=%6d us" % [exp, dts[dts.size()/2], dts[int(dts.size()*0.99)]]); quit())
func _apply() -> void:
	for n in _walk(m):
		if exp == "anim" and n is AnimationPlayer: n.process_mode = Node.PROCESS_MODE_DISABLED
		if exp == "views" and n.get_script() == load("res://src/game/player.gd"): n.set_process(false)
		if exp == "pres" and n.name == "Presentation": n.process_mode = Node.PROCESS_MODE_DISABLED
		if exp == "skel" and n is Skeleton3D: n.process_mode = Node.PROCESS_MODE_DISABLED
		if exp == "stadium" and n.name == "Stadium": n.process_mode = Node.PROCESS_MODE_DISABLED
func _walk(n: Node) -> Array:
	var o := [n]
	for c in n.get_children(): o.append_array(_walk(c))
	return o
