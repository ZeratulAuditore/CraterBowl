extends "res://tests/visual/harness.gd"
## C06a / #98: a linebacker meets the QB and drives him back before diving. The ball is
## spotted where the carrier's forward progress stopped (the QB is put back there) and the
## overlay calls it out. Real main scene, real snap key path, real sim whistle.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.auto_next = false
	game.opening_kickoff = false
	game.ai.defense_enabled = false
	game.series.start(0, 40.0)
	game.set_controlled(game.my_id)
	await _frames(5)
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	game._unhandled_key_input(ev)
	await _frames(30)
	var c = game.world.carrier()
	check(c != null and c.team == 0, "QB has the snap")
	var cx: float = game.world.field.width / 2.0
	c.position = Vector2(cx, 38.0)
	var lb = game.world.find_role(1, game.Athlete.Role.LB)
	lb.position = Vector2(cx, 39.6)
	lb.facing = Vector2(0, -1)
	var contact_y := INF
	game.pov_enabled = false
	for i in 40:
		lb.position = c.position + Vector2(0, 0.75)   # keeps leaning in: bodies overlap, QB gives ground
		await physics_frame
		if contact_y == INF and lb.position.distance_to(c.position) <= game.T.CONTACT_REACH:
			contact_y = c.position.y
	var driven_y: float = c.position.y
	check(contact_y - driven_y > 1.0, "QB driven back %.2f yd" % (contact_y - driven_y))
	await capture("forward-progress-driven-back")
	check(game.world.tackle(lb.id), "LB dives")
	await _frames(12)
	check(game.world.phase == game.World.Phase.DEAD, "tackled")
	check(absf(game.world.dead_ball_spot.y - contact_y) < 0.2, "spot %.2f = forward progress %.2f (driven to %.2f)" % [game.world.dead_ball_spot.y, contact_y, driven_y])
	check(c.position.is_equal_approx(game.world.dead_ball_spot), "dead carrier sits at the spot")
	var ov = game.pres.overlay
	check(ov.banner.visible and ov.banner.text == "FORWARD PROGRESS", "banner: %s %s" % [ov.banner.text, ov.banner_sub.text])
	await capture("forward-progress-spot")
	finish()

func _frames(n: int) -> void:
	for i in n:
		await physics_frame
