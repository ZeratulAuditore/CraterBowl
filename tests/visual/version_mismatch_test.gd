extends "res://tests/visual/harness.gd"
## #165: a build on another protocol version is turned away with a readable reason.
## 1. Joining a host on a newer protocol: the join screen says "Update Crater Bowl to play
##    online (server is vX, you have vY)" and the player is never seated.
## 2. Queueing at a matchmaker on a newer protocol: back to the menu with the same reason.
## 3. A pre-handshake build (never says hello) is refused after HELLO_TIMEOUT.
## Version numbers are read through the constant map so this file also runs on a base tree
## without the handshake (before_after.sh), where the mismatched client simply gets in.

const NetSession := preload("res://src/net/net_session.gd")
const MMServer := preload("res://src/net/mm_server.gd")
const Lobby := preload("res://src/net/lobby.gd")
const MENU_SCENE := "res://scenes/menu.tscn"

## An old client: connects but never sends hello.
class SilentClient extends NetSession:
	func _say_hello() -> void:
		pass

var ours: int = int((load("res://src/net/protocol.gd") as Script).get_script_constant_map().get("VERSION", 0))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var launch = root.get_node("Launch")
	launch.settings_path = "user://test_version_mismatch_settings.cfg"
	launch.settings.player_name = "Rookie"
	var port := 30000 + randi() % 2000
	var newer := ours + 1
	var want := "Update Crater Bowl to play online (server is v%d, you have v%d)" % [newer, ours]

	# 1. A host one protocol version ahead, with an open lobby.
	var host = NetSession.new()
	host.name = "NewerHost"
	root.add_child(host)
	host.set("protocol_version", newer)
	check(host.host(port, func(_p): return -1, func(_p): pass) == OK, "host listening on %d" % port)
	var lobby := Lobby.new()
	lobby.add(1, "Host")
	lobby.code = "TEST0-CODE0"
	host.lobby = lobby
	host.lobby_mode = true
	host.lobby_changed.connect(func(): host.broadcast_lobby(lobby.to_dict()))

	var game = _open_game()
	game._join_game("127.0.0.1", port, {})
	for frame in 300:
		await process_frame
		if game.net.refused_reason != "":
			break
	await _refresh()
	check(game.net.refused_reason == want, "joiner refused with the version reason: '%s'" % game.net.refused_reason)
	check(game.in_lobby() and game.hud.visible and game.hud.text.contains("COULDN'T JOIN") and game.hud.text.contains(want), "join screen shows why")
	check(not game.hud.text.contains("bigger match"), "no capacity hint for a version mismatch")
	check(lobby.players.size() == 1 and game.net.my_athlete < 0, "never entered the host's lobby")
	await capture("version-mismatch-joiner-refused")

	# 2. A matchmaker one protocol version ahead.
	var mm = MMServer.new()
	mm.name = "NewerMM"
	root.add_child(mm)
	mm.set("protocol_version", newer)
	check(mm.start(port + 1) == OK, "matchmaker listening on %d" % (port + 1))
	var queued = _open_game()
	queued._queue_up({"queue": "casual", "mm": "127.0.0.1:%d" % (port + 1), "no-warmup": true})
	for frame in 300:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == MENU_SCENE:
			break
	await _refresh()
	var menu = current_scene
	check(menu != null and menu.scene_file_path == MENU_SCENE, "queue refusal returns to the menu")
	if menu != null and menu.scene_file_path == MENU_SCENE:
		check(menu.status_label.text == want and menu.status_label.is_visible_in_tree(), "menu status reads the version reason: '%s'" % menu.status_label.text)
	check(mm.mm.queue.is_empty(), "mismatched player never queued")
	await capture("version-mismatch-queue-menu")

	# 3. A build from before the handshake is refused once HELLO_TIMEOUT passes.
	var current = NetSession.new()
	current.name = "CurrentHost"
	root.add_child(current)
	check(current.host(port + 2, func(_p): return 0, func(_p): pass) == OK, "current host listening")
	var old := SilentClient.new()
	old.name = "OldClient"
	root.add_child(old)
	old.join("127.0.0.1", port + 2)
	# Game time, not wall time: --fixed-fps 60 makes HELLO_TIMEOUT (5 s) 300 frames.
	for frame in 420:
		if old.refused_reason != "" or old.my_athlete >= 0:
			break
		await process_frame
	check(old.refused_reason.begins_with("Update Crater Bowl to play online (server is v%d, you have an older build)" % ours),
		"pre-handshake client refused: '%s'" % old.refused_reason)
	check(old.my_athlete < 0, "pre-handshake client never seated")
	finish()

func _open_game():
	if current_scene != null:
		current_scene.queue_free()
	var game = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	return game

func _refresh() -> void:
	for frame in 10:
		await process_frame
