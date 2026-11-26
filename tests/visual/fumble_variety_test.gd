extends "res://tests/visual/harness.gd"
const Ball := preload("res://src/sim/ball.gd")
## Fumble rolls are a deterministic hash of the play tick, so the jog length picks the
## situation: 5 frames is one of the ~25% of rear hits on a fresh jogger that strip the ball.
const JOG_FRAMES := 5
## C06b / #99: a FRESH carrier jogging (not sprinting) upfield is dived on squarely from
## behind. Before #99 this could never fumble (no fatigue, no sprint); now the rear-hit term
## gives it a real chance and this deterministic hit strips him. Real main scene, real snap key.

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
	var W = game.World
	var cx: float = game.world.field.width / 2.0
	var lb = game.world.find_role(1, game.Athlete.Role.LB)
	game.pov_enabled = false
	c.stamina = 1.0
	var risk: float = W.fumble_risk(0.0, c.stamina, 1.0, false)
	check(risk > 0.2 and W.fumble_risk(0.0, c.stamina, -1.0, false) == 0.0, "fresh jogger: rear-hit risk %.2f, head-on 0" % risk)
	var y := 44.0
	for i in JOG_FRAMES:   # carrier jogs upfield with the linebacker on his heels
		y += game.T.RUN_SPEED / 60.0
		c.position = Vector2(cx, y)
		c.velocity = Vector2(0, game.T.RUN_SPEED)
		c.facing = Vector2(0, 1)
		c.last_sprinting = false
		c.stamina = 1.0
		lb.position = c.position - Vector2(0, 1.1)
		lb.facing = Vector2(0, 1)
		await physics_frame
	check(not c.last_sprinting and c.stamina >= game.T.FUMBLE_FRESH_STAMINA, "fresh and not sprinting")
	await capture("fumble-fresh-jogger-before-hit")
	check(game.world.tackle(lb.id), "LB dives from behind")
	var seen := []
	game.world.event.connect(func(n, _d): seen.append(n))
	for i in 20:
		await physics_frame
		if seen.has("fumble") or seen.has("tackle"):
			break
	var fumbled := seen.has("fumble")
	check(fumbled, "fresh jogging carrier stripped from behind")
	check(game.world.ball.state == Ball.State.LOOSE, "ball is loose")
	await _frames(8)
	var ov = game.pres.overlay
	check(ov.banner.visible and ov.banner.text == "FUMBLE", "banner: %s" % ov.banner.text)
	await capture("fumble-fresh-jogger-stripped")
	finish()

func _frames(n: int) -> void:
	for i in n:
		await physics_frame
