extends "res://tests/visual/harness.gd"
## #74: pick Chaosball on the Online screen, host a private match, and the lobby
## opens in Chaosball 3v3 (not classic rules with the host pressing M).

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var launch = root.get_node("Launch")
	launch.settings.player_name = "Ace"
	launch.settings.upnp = false              # never touch a real router from tests
	var menu = preload("res://scenes/menu.tscn").instantiate()
	menu.set_meta("force_menu", true)
	menu.host_port = 27000 + (Time.get_ticks_usec() + OS.get_process_id() * 7) % 2000
	root.add_child(menu)
	current_scene = menu
	await _frames(3)
	menu.pick_size = 7                        # Chaosball must still force 3v3
	menu.list_public = false
	menu.show_screen("online")
	var chaos := _button(menu.content, "Chaosball (3v3, low-g)")
	check(chaos != null, "online screen has the Chaosball rules button")
	chaos.pressed.emit()
	chaos.button_pressed = true
	check(menu.pick_mode == "chaosball", "Chaosball selected under Online")
	await capture("online-chaosball-selected")
	menu.host_match()
	for i in 120:
		await process_frame
		if current_scene != menu and current_scene != null and current_scene.is_inside_tree() and current_scene.get("lobby") != null:
			break
	var game = current_scene
	check(game != null and game.scene_file_path == launch.GAME_SCENE, "host opens the game scene")
	await _frames(10)
	check(game.is_server() and game.in_lobby(), "hosting a private lobby")
	check(game.lobby.settings.get("mode") == "chaosball", "lobby rules are Chaosball")
	check(game.lobby.settings.get("size") == 3, "lobby size is 3v3")
	check(game.hud.text.contains("Chaosball 3v3"), "lobby HUD reads Chaosball 3v3: " + game.hud.text.get_slice("\n", 1))
	check(game.hud.is_visible_in_tree(), "lobby HUD is on screen")
	await capture("private-lobby-chaosball-3v3")
	finish()

func _button(node: Node, text: String) -> Button:
	for n in node.find_children("*", "Button", true, false):
		if n.text.to_upper() == text.to_upper():
			return n
	return null

func _frames(n: int) -> void:
	for i in n:
		await process_frame
