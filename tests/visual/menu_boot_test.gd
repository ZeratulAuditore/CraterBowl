extends "res://tests/visual/harness.gd"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var menu = preload("res://scenes/menu.tscn").instantiate()
	menu.set_meta("force_menu", true)
	root.add_child(menu)
	current_scene = menu
	await process_frame
	check(menu.current == "welcome" and menu.panel.is_visible_in_tree(), "fresh profile shows first-run name prompt")
	await capture("first-run-name-prompt")
	finish()
