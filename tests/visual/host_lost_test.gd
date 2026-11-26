extends "res://tests/visual/harness.gd"
## #56: a joiner in a match whose host goes away is sent back to the menu, and the
## menu says "Host disconnected" (net_test.sh covers the SIGKILL/timeout case).

const NetSession := preload("res://src/net/net_session.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var port := 30000 + randi() % 2000
	var launch = get_root().get_node("Launch")
	launch.settings_path = "user://test_host_lost_settings.cfg"   # never leak the name into later cases
	launch.settings.player_name = "Rookie"   # home screen, not first-run
	var host = NetSession.new()
	host.name = "BareHost"
	root.add_child(host)
	check(host.host(port, func(_p): return 7, func(_p): pass) == OK, "host listening on %d" % port)

	var game = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game._join_game("127.0.0.1", port, {})
	for frame in 600:
		await process_frame
		if game.net.my_athlete >= 0:
			break
	check(game.net.my_athlete == 7, "joiner welcomed into the match (athlete %d)" % game.net.my_athlete)

	host.peer.close()   # the host quits
	for frame in 600:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/menu.tscn":
			break
	var menu = current_scene
	check(menu != null and menu.scene_file_path == "res://scenes/menu.tscn", "joiner returned to the menu")
	for frame in 20:
		await process_frame
	check(menu != null and menu.status_label.text == "Host disconnected" and menu.status_label.is_visible_in_tree(),
		"menu status reads 'Host disconnected'")
	await capture("host-lost-menu-status")
	host.queue_free()
	finish()
