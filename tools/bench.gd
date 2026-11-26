extends SceneTree
## Performance benchmark. Two parts, both headless and deterministic:
##   1. SIM: an all-bot 7v7 game at 60 Hz; per-tick cost of each sim stage.
##   2. SCENE: the real main scene; per-frame script cost (process + physics).
## Prints one `BENCH <key>=<value>` line per metric so scripts can parse/compare.
##
##   godot --headless --fixed-fps 60 --path . -s res://tools/bench.gd [-- --minutes=4 --frames=2400 --size=7 --toss=1]
## --fixed-fps 60 makes every frame exactly one sim tick, run uncapped, so a frame's wall
## time = the full per-tick cost (physics + process + scene). Gate on p50: medians shrug off
## other processes stealing the CPU; means and Performance monitors (1 s averages) do not.
## The scene's opening coin toss is pinned (`--toss`, default 1) so every run plays the same
## game: an unseeded toss made the object-growth check a coin flip (#169).
##
## See docs/optimization/README.md for budgets and how to read the numbers.
const World := preload("res://src/sim/world.gd")
const Match := preload("res://src/sim/match.gd")
const Roster := preload("res://src/sim/roster.gd")
const AI := preload("res://src/sim/ai.gd")

const DT := 1.0 / 60.0

var _args := {}
var _main: Node
var _frame := 0
var _frames := 600
var _frame_us: Array = []
var _last_us := 0
var _objects0 := 0
var _objects1 := 0
var _classes: Array = []  # node-class histograms at the three leak checkpoints

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_frames = int(_args.get("frames", "600"))
	if _args.get("only", "") != "scene":
		_bench_sim(float(_args.get("minutes", "4")), int(_args.get("size", "7")))
	if _args.get("only", "") == "sim":
		quit()
		return
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set("auto_next", true)
	_main.set("toss_seed", int(_args.get("toss", "1")))
	root.add_child(_main)
	process_frame.connect(_on_frame)

## Stage timings for an all-bot game (the same work a host does every physics tick).
func _bench_sim(minutes: float, size: int) -> void:
	var w := World.new()
	Roster.new().build(w, size)
	var m := Match.new(w)
	m.start(0, 25.0)
	var ai := AI.new()
	var t_presnap: Array = []
	var t_think: Array = []
	var t_step: Array = []
	var t_total: Array = []
	var dead_t := 0.0
	var ticks := int(minutes * 60.0 * 60.0)
	for i in ticks:
		var t0 := Time.get_ticks_usec()
		m.tick(DT)
		var t1 := Time.get_ticks_usec()
		ai.presnap_tick(w, [], DT, m.downs.down, m.downs.distance())
		var t2 := Time.get_ticks_usec()
		var inputs := ai.think(w, [])
		var t3 := Time.get_ticks_usec()
		w.step(inputs, DT)
		var t4 := Time.get_ticks_usec()
		t_presnap.append(t2 - t1)
		t_think.append(t3 - t2)
		t_step.append(t4 - t3)
		t_total.append(t4 - t0)
		if w.phase == World.Phase.DEAD:
			dead_t += DT
			if dead_t > 0.5:
				m.next_play()
				dead_t = 0.0
		if m.is_final():
			m.start(0, 25.0)
	_report("sim_presnap", t_presnap)
	_report("sim_think", t_think)
	_report("sim_step", t_step)
	_report("sim_tick", t_total)
	print("BENCH sim_ticks=%d" % ticks)

func _on_frame() -> void:
	_frame += 1
	# Leak check: features allocate lazily on first use (first replay's hint bar, the play
	# picker's buttons, ...). The first half of the run is warm-up: in the pinned scenario it
	# covers the kickoff, the first replay and the first play-picker build (#169). A leak keeps
	# growing, so it shows in BOTH quarter-windows after that. Reported = the smaller window.
	if _frame == 30 + _frames / 2:
		_objects0 = int(Performance.get_monitor(Performance.OBJECT_COUNT))
		_classes.append(_node_classes())
	if _frame == 30 + 3 * _frames / 4:
		_objects1 = int(Performance.get_monitor(Performance.OBJECT_COUNT))
		_classes.append(_node_classes())
	var now := Time.get_ticks_usec()
	if _frame > 30:  # skip warm-up (scene build, first imports)
		_frame_us.append(now - _last_us)
	_last_us = now
	# Keep plays flowing so the scene exercises LIVE/DEAD/PRESNAP, not just presnap.
	if _main.world.phase == World.Phase.PRESNAP and _frame % 90 == 0:
		_main.world.snap()
	if _frame >= _frames + 30:
		_report("scene_frame", _frame_us)
		var objs := int(Performance.get_monitor(Performance.OBJECT_COUNT))
		print("BENCH scene_nodes=%d" % int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		_classes.append(_node_classes())
		print("BENCH scene_object_growth=%d" % mini(_objects1 - _objects0, objs - _objects1))
		print("BENCH scene_object_windows=%d,%d" % [_objects1 - _objects0, objs - _objects1])
		for i in 2:  # which node classes grew, so a failure names its suspect
			for k in _classes[i + 1]:
				var d: int = _classes[i + 1][k] - _classes[i].get(k, 0)
				if d != 0:
					print("BENCH leak_window%d %s %+d" % [i + 1, k, d])
		print("BENCH static_mem_mb=%.1f" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0))
		quit()

## Live node count per class (plus script file), e.g. {"Button": 10, "Node3D:player.gd": 14}.
func _node_classes() -> Dictionary:
	var out := {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var s: Script = n.get_script()
		var key := n.get_class() + (":" + s.resource_path.get_file() if s else "")
		out[key] = int(out.get(key, 0)) + 1
		stack.append_array(n.get_children(true))
	return out

func _report(key: String, samples: Array) -> void:
	if samples.is_empty():
		return
	var s := samples.duplicate()
	s.sort()
	var sum := 0
	for v in s:
		sum += v
	var mean := float(sum) / s.size()
	var p99: int = s[mini(s.size() - 1, int(s.size() * 0.99))]
	print("BENCH %s_mean_us=%.1f" % [key, mean])
	print("BENCH %s_p50_us=%d" % [key, s[s.size() / 2]])
	print("BENCH %s_p99_us=%d" % [key, p99])
	print("BENCH %s_max_us=%d" % [key, s[-1]])
