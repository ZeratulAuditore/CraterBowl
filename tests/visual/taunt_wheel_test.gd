extends "res://tests/visual/harness.gd"
## #139: hold C opens the radial taunt wheel at screen centre; a mouse drag up and to the
## right highlights the "Nope" slice. Driven through main's real key and mouse handlers.
## The mouse-wheel event and dynamic lookups keep this runnable on older trees for
## before/after captures (their checks fail there, which is expected).

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.auto_next = false
	game.opening_kickoff = false
	game.series.start(0, 30.0)
	game.set_controlled(game.my_id)
	game.set("mouse_captured_override", true)
	for frame in 60:   # let the camera settle on the huddle
		await process_frame
	var wheel_ev := InputEventMouseButton.new()
	wheel_ev.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_ev.pressed = true
	game._unhandled_input(wheel_ev)   # used to scroll the old taunt list; now unbound
	var c := InputEventKey.new()
	c.keycode = KEY_C
	c.pressed = true
	game._unhandled_key_input(c)
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(60, -60)
	game._unhandled_input(drag)
	var w = game.get("taunt_wheel")
	check(w != null and w.open and w.visible, "holding C opens the taunt wheel")
	check(w != null and w.highlighted() == "nope", "drag up-right highlights Nope")
	for frame in 10:   # past the fade-in
		await process_frame
	if w != null:
		var r: Rect2 = w.get_global_rect()
		check(r.get_center().distance_to(root.get_visible_rect().get_center()) < 1.0, "wheel is centred on screen")
		check(w.modulate.a == 1.0, "fade-in settled before the capture")
	await capture("taunt-wheel-open")
	c = InputEventKey.new()
	c.keycode = KEY_C
	c.pressed = false
	game._unhandled_key_input(c)
	check(w != null and not w.open and game.views[game.controlled_id].emote_id == "nope", "release performs Nope")
	finish()
