extends "res://tests/visual/harness.gd"
## #189 (D08a): you are the punt returner. While the bot's punt is in the air the pill
## offers the fair catch; the real Space key signals it (raised arm + FAIR CATCH over
## the returner); the catch ends the play with a FAIR CATCH dead-ball line.
## Real main scene, real key path, real sim. Return-team bots hold still.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.auto_next = false
	game.opening_kickoff = false
	game.ai.defense_enabled = false
	var series = game.series
	var w = game.world
	var mine: int = w.get_athlete(game.my_id).team
	series.start(1 - mine, 30.0)
	series.downs.down = 4
	check(series.call_kick("punt"), "bot offense punts on 4th down")
	var ret = w.returner()
	game.set_controlled(ret.id)
	await _frames(5)
	check(w.snap(), "snap")
	for i in 90:
		await physics_frame
		if w.kicked:
			break
	check(w.kicked and w.ball.state == 1, "punt in the air")
	var ai = game.ai
	ret.position = ai._landing_point(w)
	await _frames(45)   # camera settles on the returner; the punt is still climbing
	var ov = game.pres.overlay
	check(ov.status_l.text == "PRESS SPACE FOR A FAIR CATCH", "returner prompt: %s" % ov.status_l.text)
	await capture("fair-catch-prompt")
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	game._unhandled_key_input(ev)
	check(w.get("fair_catch_id") == ret.id, "Space signals the fair catch")
	await _frames(30)
	var view = game.views[ret.id]
	var label = view.find_child("FairCatchSignal", true, false)
	check(label != null and label.visible, "FAIR CATCH shown over the returner")
	check(ov.status_l.text.begins_with("FAIR CATCH SIGNALED"), "pill confirms: %s" % ov.status_l.text)
	await capture("fair-catch-signal")
	for i in 300:
		await physics_frame
		if w.phase == 2:
			break
	await _frames(20)
	check(w.phase == 2 and game.last_whistle == "FAIR CATCH", "play dead on the catch (%s)" % game.last_whistle)
	check(ov.status_l.text == "FAIR CATCH", "dead-ball line: %s" % ov.status_l.text)
	check(label != null and not label.visible, "signal label clears at the whistle")
	await capture("fair-catch-whistle")
	finish()

func _frames(n: int) -> void:
	for i in n:
		await physics_frame
