extends "res://tests/visual/harness.gd"
## #167: the host's short play clock stays visible on subsequent downs.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = preload("res://scenes/main.tscn").instantiate()
	game.opening_kickoff = false
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	game.set_process(false)
	game.pres.set_process(false)
	game._host_game(0, game.host_options({"playclock": 4, "no-lobby": true}))
	check(game.is_server(), "host started without a lobby")
	await process_frame
	for view in game.views:
		view.set_process(false)
		if view.anim != null and view.anim.is_playing():
			view.anim.seek(0.0, true)
			view.anim.pause()
	_refresh(game)
	check(game.pres.overlay.play_clock_l.text == "PLAY :04", "opening play shows four seconds")
	await capture("opening-play")

	var snap := InputEventKey.new()
	snap.keycode = KEY_SPACE
	snap.pressed = true
	game._unhandled_key_input(snap)
	check(game.world.phase == game.World.Phase.LIVE, "host snaps through Space")
	game.series.last_result = {"type": "incomplete"}
	game.world.phase = game.World.Phase.DEAD
	game.next_play()
	_refresh(game)
	check(game.series.downs.down == 2, "the next down is ready")
	check(game.pres.overlay.play_clock_l.text == "PLAY :04", "second play shows four seconds")
	await capture("second-play")
	finish()

func _refresh(game) -> void:
	for view in game.views:
		view.sync()
	game._process(1.0)
	game.pres._process(1.0)
