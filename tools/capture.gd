extends SceneTree
## Render the real main scene and save PNG screenshots at chosen frames.
## Run it through scripts/shot.sh, which runs it under Xvfb with Mesa software
## GL: real pixels, no window on the desktop. Plain `--headless` can't render.
##
## User args (after `--`), all optional:
##   --out=PREFIX          file prefix; writes PREFIX_0060.png (default user://shot)
##   --frames=60,200       frames to capture (default 120)
##   --every=N             also capture every N frames (animation strips)
##   --do=F:ACTION,...     main.do_action({"a": ACTION}) at frame F (snap, tackle, ...)
##   --snap=F              shorthand for --do=F:snap
##   --press=F:KEY[:HOLD],...  real key event via Input.parse_input_event at frame F,
##                         released after HOLD frames (default 1). KEY is a Godot key
##                         name: V, Space, Tab, Enter, W, Shift...
##   --call=F:METHOD,...   main.call(METHOD) at frame F (e.g. next_play)
## Every other user arg (--size=5, --practice=..., --replay=...) reaches main.gd unchanged.
## Frames are physics frames at --fixed-fps 60 (shot.sh sets it), the same clock game_flow.gd uses.

var main
var frame := 0
var out := "user://shot"
var shots: Array[int] = []
var every := 0
var events := {}   # frame -> Array[Callable]
var last_frame := 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		var v := kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"out": out = v
			"frames":
				for s in v.split(",", false): shots.append(int(s))
			"every": every = int(v)
			"snap": _at(int(v), func(): main.do_action({"a": "snap"}))
			"do":
				for item in v.split(",", false):
					var p := item.split(":")
					var act := p[1]
					_at(int(p[0]), func(): print("CAPTURE do %s -> %s" % [act, main.do_action({"a": act})]))
			"call":
				for item in v.split(",", false):
					var p := item.split(":")
					var m := p[1]
					_at(int(p[0]), func(): main.call(m))
			"press":
				for item in v.split(",", false):
					var p := item.split(":")
					var code := OS.find_keycode_from_string(p[1])
					if code == KEY_NONE:
						push_error("capture: unknown key name '%s'" % p[1])
						continue
					var hold := int(p[2]) if p.size() > 2 else 1
					_at(int(p[0]), func(): _key(code, true))
					_at(int(p[0]) + hold, func(): _key(code, false))
	if shots.is_empty() and every == 0:
		shots.append(120)
	last_frame = shots.max() if not shots.is_empty() else 0
	for f in events.keys():
		last_frame = maxi(last_frame, f)
	if every > 0:
		last_frame = maxi(last_frame, 600 if shots.is_empty() else last_frame)
	var dir := out.get_base_dir()
	if dir != "" and not dir.begins_with("user://"):
		DirAccess.make_dir_recursive_absolute(dir)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _at(f: int, c: Callable) -> void:
	if not events.has(f):
		events[f] = []
	events[f].append(c)

func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _physics_process(_d: float) -> bool:
	frame += 1
	for c in events.get(frame, []):
		c.call()
	return false

func _process(_d: float) -> bool:
	# Capture in _process so the frame has been drawn at least once since the last physics tick.
	if frame in shots or (every > 0 and frame > 0 and frame % every == 0):
		var img := root.get_viewport().get_texture().get_image()
		var path := "%s_%04d.png" % [out, frame]
		var err := img.save_png(path)
		print("SHOT %s (%s)" % [ProjectSettings.globalize_path(path), error_string(err)])
		shots.erase(frame)
	return frame > last_frame
