extends "res://tests/visual/harness.gd"
## C04c (#89): the end zones follow the period. Captures the far end zone in Q1
## (NEBULA paint ahead of the HELIOS offense) and right after the switch to Q2
## (HELIOS paint ahead, SWITCH ENDS banner), with the ball still at the same spot.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.auto_next = false
	game.opening_kickoff = false
	var series = game.series
	series.clock.quarter_length = 120.0
	series.start(0, 82.0)
	game.set_controlled(game.my_id)
	var far: Label3D = game.field_root.get_node("EndZoneName1")
	await _refresh()
	check(series.clock.label() == "Q1 2:00", "Q1 quarters clock (%s)" % series.clock.label())
	check(far.text == "NEBULA", "Q1: HELIOS attacks the NEBULA end zone")
	await capture("switch-ends-q1")

	series.clock.remaining = 0.0
	series.last_result = {"type": "tackle", "spot": 84.0, "team": 0}
	var out: Dictionary = series.next_play()
	await _refresh()
	check(out.get("outcome", "") == "quarter" and out.get("switch_ends", false), "Q1 -> Q2 switches ends")
	check(series.clock.label() == "Q2 2:00", "Q2 clock (%s)" % series.clock.label())
	check(absf(game.world.los_y - 84.0) < 0.01 and series.downs.offense_team == 0, "same offense at the same spot")
	check(far.text == "HELIOS", "Q2: HELIOS attacks the HELIOS-painted end")
	check(game.pres.overlay.banner.visible and game.pres.overlay.banner.text == "SWITCH ENDS", "SWITCH ENDS banner")
	await capture("switch-ends-q2")
	finish()

func _refresh() -> void:
	for frame in 8:
		await process_frame
