extends "res://tests/visual/harness.gd"
## #142: before the snap the whole offense holds its line-up spot (turning only),
## and a set defender needs a Space double-tap to roam: one press does nothing.
## Driven through the real key handler and physics step, like a player would.

const DT := 1.0 / 60.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	game.auto_next = false
	game.opening_kickoff = false
	var w = game.world

	# Offense: a full second of sprint input must not move anyone before the snap.
	game.series.start(0, 30.0)
	game.set_controlled(game.my_id)
	var start := {}
	for a in w.athletes:
		if a.team == w.offense_team:
			start[a.id] = a.position
	game.input_override = Vector2(1, 0)
	game.sprint_override = true
	for i in 60:
		game._physics_process(DT)
	var drift := _max_drift(w, start)
	check(w.phase == w.Phase.PRESNAP, "offense still pre-snap")
	check(drift < 0.01, "no offensive athlete moved pre-snap (max %.3f yd)" % drift)
	game.input_override = null
	game.sprint_override = null
	var label := _evidence()
	label.text = "OFFENSE PRE-SNAP\n1.0 s of sprint-right input on your QB\nfurthest any offensive athlete moved: %.2f yd" % drift
	await _settle(game)
	await capture("presnap-offense-held")

	# Defense: one Space press keeps the stance, a double-tap breaks it.
	game.series.start(1, 30.0)
	game.set_controlled(game.my_id)
	var me = w.get_athlete(game.my_id)
	check(me.role != game.Athlete.Role.DL and me.set_lock, "human defender (%s) lines up set" % me.role)
	_space(game)
	var one := _push(game, me)
	check(me.set_lock and one < 0.01, "one Space press: still set (moved %.3f yd)" % one)
	label.text = "DEFENSE PRE-SNAP: ONE SPACE PRESS\nstill set, moved %.2f yd" % one
	await _settle(game)
	await capture("presnap-defense-one-press")

	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 450:   # let the double-tap window lapse (wall clock)
		await process_frame
	_space(game)
	_space(game)
	var two := _push(game, me)
	check(w.phase == w.Phase.PRESNAP and not me.set_lock and two > 1.0, "double-tap: roaming without a snap (moved %.2f yd)" % two)
	label.text = "DEFENSE PRE-SNAP: SPACE DOUBLE-TAP\nroaming, moved %.2f yd" % two
	await _settle(game)
	await capture("presnap-defense-double-tap")
	finish()

func _space(game) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	game._unhandled_key_input(ev)

## Half a second of strafe input; returns how far the athlete moved.
func _push(game, a) -> float:
	var p0: Vector2 = a.position
	game.input_override = Vector2(1, 0)
	for i in 30:
		game._physics_process(DT)
	game.input_override = null
	return a.position.distance_to(p0)

func _max_drift(w, start: Dictionary) -> float:
	var d := 0.0
	for id in start:
		d = maxf(d, w.get_athlete(id).position.distance_to(start[id]))
	return d

## Snap every view and the camera to the final sim state so the capture is reproducible.
func _settle(game) -> void:
	game._render()
	for v in game.views:
		v.interpolate(1.0)
	for i in 6:
		await process_frame
	game.cam_yaw = game._camera_target_yaw()
	game.camera_follow = game.player.global_position
	game._update_camera(DT)

func _evidence() -> Label:
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var label := Label.new()
	label.position = Vector2(32, 124)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	layer.add_child(label)
	return label
