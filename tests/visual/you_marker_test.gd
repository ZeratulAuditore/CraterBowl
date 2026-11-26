extends "res://tests/visual/harness.gd"
## #141: the athlete you control is marked only by the team-colored ground ring. The floating
## chevron that used to hover over your head is gone in every mode: a match, an instant replay
## and the training ground. You never switch athletes, so the marker follows one seat all match.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.auto_next = false
	game.auto_replay = false
	game.opening_kickoff = false
	game.pov_enabled = false   # follow camera behind the player, where the chevron used to show
	game.ai.defense_enabled = false
	game.series.start(0, 30.0)
	game.set_controlled(game.my_id)
	await _frames(40)
	_check_marker(game, "match")
	await capture("you-marker-match")

	game.start_practice("hub")
	await _frames(40)
	check(game.drill != null and game.drill.kind == "hub", "training ground loaded")
	_check_marker(game, "training")
	await capture("you-marker-training")

	# Instant replay of a real play (snap through the real key path, then a touchdown).
	game.configure(7)
	game.ai.defense_enabled = false
	game.series.start(0, 30.0)
	game.set_controlled(game.my_id)
	await _frames(5)
	_press(game, KEY_SPACE)
	await _frames(30)
	check(game.world.phase == game.World.Phase.LIVE, "snap through the real key path")
	game.world.carrier().position = Vector2(26, 101.0)
	await _frames(5)
	check(game.world.phase == game.World.Phase.DEAD, "play over")
	_press(game, KEY_V)
	check(game.replay_active, "V starts the instant replay")
	game.replay.paused = true
	game.replay.time = game.replay.clip_start + 10.0   # fixed replay frame (QB just after the snap)
	await _frames(200)   # paused: the live TOUCHDOWN banner (3 s) expires and the camera settles
	_check_marker(game, "replay")
	await capture("you-marker-replay")
	finish()

## The acceptance checks, run in each mode.
func _check_marker(game, mode: String) -> void:
	var pres = game.pres
	var pv: Node3D = game.player
	check(game.controlled_id == game.my_id, "%s: you control your own seat (no switching)" % mode)
	check(game.find_child("Chevron", true, false) == null and not ("chevron" in pres), "%s: no chevron node" % mode)
	var at := Vector2(pv.global_position.x, pv.global_position.z)
	check(pres.ring.visible and Vector2(pres.ring.position.x, pres.ring.position.z).distance_to(at) < 0.05,
		"%s: ground ring under your athlete" % mode)
	# Catches any renamed overhead marker too: no presentation mesh floats above your head.
	var overhead: Array = pres.get_children().filter(func(n):
		return n is GeometryInstance3D and n.visible and n.global_position.y > 1.5 \
			and Vector2(n.global_position.x, n.global_position.z).distance_to(at) < 1.0)
	check(overhead.is_empty(), "%s: nothing floats over your athlete (%s)" % [mode, str(overhead.map(func(n): return n.name))])

func _press(game, code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	game._unhandled_key_input(ev)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame
