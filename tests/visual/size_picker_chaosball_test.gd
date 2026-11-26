extends "res://tests/visual/harness.gd"
## #83: on the Online screen, Chaosball locks the Size row to a dimmed 3v3; Classic
## brings back the earlier 7v7 pick.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var launch = root.get_node("Launch")
	launch.settings.player_name = "Ace"
	launch.settings.upnp = false              # never touch a real router from tests
	var menu = preload("res://scenes/menu.tscn").instantiate()
	menu.set_meta("force_menu", true)
	root.add_child(menu)
	current_scene = menu
	await _frames(3)
	menu.pick_size = 7
	menu.pick_mode = "classic"
	menu.show_screen("online")
	await _frames(2)
	check(_row(menu) == "7/enabled", "Classic shows the 7v7 pick, row enabled: " + _row(menu))
	await capture("online-classic-size-7v7")
	var chaos := _button(menu.content, "Chaosball (3v3, low-g)")
	chaos.pressed.emit()
	chaos.button_pressed = true
	await _frames(2)
	check(_row(menu) == "3/disabled", "Chaosball locks the Size row to 3v3: " + _row(menu))
	await capture("online-chaosball-size-locked")
	var classic := _button(menu.content, "Classic")
	classic.pressed.emit()
	classic.button_pressed = true
	await _frames(2)
	check(_row(menu) == "7/enabled" and menu.pick_size == 7, "Classic restores 7v7: " + _row(menu))
	finish()

func _row(menu) -> String:
	var on := []
	var enabled := 0
	for s in [3, 5, 7]:
		var b := _button(menu.content, "%dv%d" % [s, s])
		if b == null:
			return "missing"
		if b.button_pressed:
			on.append(s)
		if not b.disabled:
			enabled += 1
	return "%s/%s" % [",".join(on), "enabled" if enabled == 3 else ("disabled" if enabled == 0 else "mixed")]

func _button(node: Node, text: String) -> Button:
	for n in node.find_children("*", "Button", true, false):
		if n.text.to_upper() == text.to_upper():
			return n
	return null

func _frames(n: int) -> void:
	for i in n:
		await process_frame
