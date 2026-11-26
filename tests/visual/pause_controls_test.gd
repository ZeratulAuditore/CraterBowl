extends "res://tests/visual/harness.gd"
## #138: the pause menu's Controls list shows the Gridiron default keys
## (R dash, T timeout, C taunt, Q/E spin, F dive, Enter next play).

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
	var launch = root.get_node("/root/Launch")
	launch.settings.bindings = {}
	for i in 3:
		await process_frame
	launch.open_overlay()
	await process_frame
	var button: Button = launch._overlay.find_child("ControlsButton", true, false)
	button.pressed.emit()
	for i in 3:
		await process_frame
	var grid: GridContainer = launch._overlay.find_child("ControlsBindings", true, false)
	var shown := {}
	var kids := grid.get_children()
	for i in range(0, kids.size() - 1, 2):
		shown[kids[i].text] = kids[i + 1].text
	var want := {"Dash (when charged)": "R", "Team timeout": "T", "Taunt (wheel picks)": "C",
		"Next play": "Enter", "Spin left (pre-snap: play picker)": "Q", "Spin right": "E",
		"Dive / tackle (pre-snap: cycle route)": "F", "Handoff": "G", "Move up": "W"}
	for label in want:
		check(shown.get(label, "") == want[label], "%s shows %s (%s)" % [label, want[label], shown.get(label, "missing")])
	var notes: Label = launch._overlay.find_child("ControlsNotes", true, false)
	check(notes.text.find("C performs") >= 0, "taunt note names C")
	check(grid.get_global_rect().end.y <= root.get_visible_rect().size.y, "whole list fits on screen")
	await capture("pause-controls-gridiron")
	finish()
