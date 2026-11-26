extends "res://tests/visual/harness.gd"
## #130: every match plays quarters. A default vs-bots match opens at Q1 2:30 on the
## scorebug, the held Tab scoreboard and the stadium screens; no surface says H1/H2.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.auto_next = false
	game.opening_kickoff = false
	var series = game.series
	series.start(0, 25.0)
	game.set_controlled(game.my_id)
	series._setup_formation()
	check(series.clock.quarter == 1 and is_equal_approx(series.clock.quarter_length, 150.0), "default match: 2:30 quarters, Q1")
	_tab(game, true)   # hold Tab through the real input handler
	await _settle()
	var overlay = game.pres.overlay
	check(overlay.clock_l.text == "Q1 2:30", "scorebug shows Q1 2:30 (%s)" % overlay.clock_l.text)
	check(overlay.scoreboard.visible and overlay.scoreboard_label.text.contains("Q1 2:30"), "Tab scoreboard shows Q1 2:30")
	check(game.hud.text.contains("Q1 2:30") and not game.hud.text.contains("H1"), "HUD clock line shows Q1, never H1")
	for screen in game.pres.stadium.jumbo_labels:
		check(screen.text.ends_with("\nQ1 2:30"), "stadium screen shows Q1 2:30 (%s)" % screen.text.replace("\n", " / "))
	await capture("quarter-clock-q1-tab-board")
	_tab(game, false)
	finish()

func _tab(game, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_TAB
	e.pressed = pressed
	game._input(e)

## Settle the overlay (it refreshes text at 10-20 Hz) with both clocks held still, so the
## capture doesn't depend on how many frames ran (#124).
func _settle() -> void:
	var clock = (current_scene as Node).get("series").clock
	for frame in 8:
		clock.play_clock = 12.0
		clock.remaining = 150.0
		await process_frame
