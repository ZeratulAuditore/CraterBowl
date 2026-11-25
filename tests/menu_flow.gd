extends SceneTree
## Out-of-game flow through the real menu scene + Launch autoload + an in-process
## matchmaker: first-run name, server browser, every launch path, public hosting,
## leave to menu, rebinding via real key events, gamepad, Esc overlay.
## Run: godot --headless --path . --fixed-fps 60 -s res://tests/menu_flow.gd -- --settings-file=user://test_menu_settings.cfg

const MMServer := preload("res://src/net/mm_server.gd")
const MMClient := preload("res://src/net/mm_client.gd")
const MM_PORT := 24811
const HOST_PORT := 24812

class Rec:
	var opts := {}
	var real
	var settings:
		get: return real.settings
	func start_game(o: Dictionary) -> void: opts = o
	func save_settings() -> void: real.save_settings()
	func version() -> String: return real.version()

var launch
var menu
var mms
var fake_host
var rec := Rec.new()
var frame := 0
var ok := true
var steps: Array = []

func check(cond: bool, msg: String) -> void:
	print(("  MENU OK   " if cond else "  MENU FAIL ") + msg)
	if not cond:
		ok = false

func _btn(root_node: Node, text: String) -> Button:
	for n in root_node.find_children("*", "Button", true, false):
		if n.text.to_upper() == text.to_upper():
			return n
	return null

func _key(code: int, pressed: bool = true) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	root.push_input(ev)

func _initialize() -> void:
	steps = [[1, _setup]]

func _setup() -> void:
	launch = root.get_node("Launch")
	rec.real = launch
	check(launch.settings_path == "user://test_menu_settings.cfg", "test settings file in use")
	launch.settings = launch.SettingsStore.new()   # fresh: no name yet
	launch.settings.matchmaker = "127.0.0.1:%d" % MM_PORT
	launch.settings.upnp = false                  # never touch a real router from tests
	mms = MMServer.new()
	mms.name = "TestMM"
	root.add_child(mms)
	check(mms.start(MM_PORT) == OK, "matchmaker up")
	menu = load("res://scenes/menu.tscn").instantiate()
	menu.set_meta("force_menu", true)
	menu.profile_path = "user://test_menu_profile.json"
	menu.leaderboard_path = "user://test_menu_lb.json"
	menu.ranked_path = "user://test_menu_ranked.json"
	menu.replay_dir = "user://test_menu_replays"
	menu.host_port = HOST_PORT
	root.add_child(menu)
	current_scene = menu
	steps += [
		[3, func(): check(menu.current == "welcome", "first run asks for a name")],
		[4, func():
			menu.content.find_child("NameEdit", true, false).text = "x"
			_btn(menu.content, "Continue").pressed.emit()
			check(menu.current == "welcome" and menu.status_label.text.find("2-16") >= 0, "bad name rejected")],
		[5, func():
			menu.content.find_child("NameEdit", true, false).text = "Ace"
			_btn(menu.content, "Continue").pressed.emit()
			check(menu.current == "online", "name accepted -> online screen")
			check(launch.settings.player_name == "Ace" and FileAccess.file_exists("user://test_menu_settings.cfg"), "name saved")],
		[6, func():
			fake_host = MMClient.new()
			root.add_child(fake_host)
			fake_host.connected.connect(func(): fake_host.register_lobby({"code": "AAAAA-BBBBB", "name": "Zed's match", "size": 5, "players": 3}))
			fake_host.open("127.0.0.1", MM_PORT)],
		[300, func():
			var b = menu.browser
			check(b != null and b.state == "online", "browser connected to matchmaker")
			check(b != null and b.last_list.size() == 1 and b.last_list[0]["name"] == "Zed's match", "browser lists the public lobby")
			menu.launch = rec
			var j := _btn(b, "Join")
			check(j != null, "join button shown")
			if j: j.pressed.emit()
			check(rec.opts == {"join": "AAAAA-BBBBB"}, "browser join -> join by code %s" % str(rec.opts))],
		[301, func():
			var code: LineEdit = menu.content.find_child("JoinCode", true, false)
			code.text = "nope"
			_btn(menu.content, "Join").pressed.emit()
			check(menu.status_label.text.find("invite code") >= 0, "bad code rejected")
			var real_code: String = preload("res://src/net/invite_code.gd").encode("10.0.0.5", 24565)
			code.text = "  " + real_code.to_lower() + " "
			rec.opts = {}
			_btn(menu.content, "Join").pressed.emit()
			check(rec.opts == {"join": real_code}, "manual join normalizes code %s" % str(rec.opts))
			_btn(menu.content, "Quick match").pressed.emit()
			check(rec.opts.get("queue") == "casual" and rec.opts.get("mm") == "127.0.0.1:%d" % MM_PORT and rec.opts.get("host-port") == "24566", "quick match -> casual queue %s" % str(rec.opts))
			_btn(menu.content, "Ranked").pressed.emit()
			check(rec.opts.get("queue") == "competitive", "ranked -> competitive queue")],
		[302, func():
			menu.show_screen("practice")
			_btn(menu.content, "Tackling").pressed.emit()
			check(rec.opts == {"practice": "tackling"}, "practice launch")
			menu.show_screen("bots")
			_btn(menu.content, "3v3").pressed.emit()
			_btn(menu.content, "Chaosball (3v3, low-g)").pressed.emit()
			_btn(menu.content, "Kick off").pressed.emit()
			check(rec.opts == {"size": "3", "mode": "chaosball"}, "vs bots launch %s" % str(rec.opts))
			for s in ["locker", "leaders", "replays", "settings"]:
				menu.show_screen(s)
				check(menu.current == s and menu.content.get_child_count() > 1, "%s screen builds" % s)],
		[303, func():
			menu.launch = launch
			_btn(menu.content, "Snap / hike")
			var bind: Button = menu.content.find_child("Bind_snap", true, false)
			bind.pressed.emit()
			_key(KEY_K)],
		[306, func():
			check(launch.settings.bindings.get("snap") == KEY_K, "rebind through real key press")
			check(launch._xlate.get(KEY_K) == KEY_SPACE, "translation live")
			menu.show_screen("online")
			menu.pick_size = 3
			menu.list_public = true
			menu.host_match()],
		[420, func():
			var g = current_scene
			check(g != null and g.scene_file_path == launch.GAME_SCENE, "host -> game scene")
			check(g.is_server() and g.lobby.code != "", "hosting a lobby (%s)" % g.lobby.code)
			check(g.match_size == 3, "size from menu")
			check(g.player_name == "Ace", "name from settings")
			check(g.get_node_or_null("Advertiser") != null, "public lobby advertiser attached")],
		[800, func():
			var l: Array = mms.registry.listing(mms._now())
			var mine := l.filter(func(e): return e["name"] == "Ace's match")
			check(mine.size() == 1 and mine[0]["code"] == current_scene.lobby.code and mine[0]["size"] == 3, "public lobby registered %s" % str(mine))
			launch.go_to_menu("Left match")],
		[830, func():
			check(current_scene != null and current_scene.scene_file_path == launch.MENU_SCENE, "leave -> back at menu")],
		[900, func():
			check(mms.registry.listing(mms._now()).filter(func(e): return e["name"] == "Ace's match").is_empty(), "lobby unlisted after leaving")
			launch.start_game({"practice": "passing"})],
		[960, func():
			var g = current_scene
			check(g.drill != null and g.drill.kind == "passing", "practice via Launch")
			check(g.world.phase == g.World.Phase.PRESNAP, "presnap")
			_key(KEY_SPACE)],
		[962, func():
			var g = current_scene
			check(g.world.phase == g.World.Phase.PRESNAP, "old Space key disabled after rebind")
			_key(KEY_K)],
		[964, func():
			var g = current_scene
			check(g.world.phase != g.World.Phase.PRESNAP, "rebound K snaps the ball (real input path)")
			_key(KEY_K, false)
			var m := InputEventJoypadMotion.new()
			m.axis = JOY_AXIS_LEFT_X
			m.axis_value = 1.0
			root.push_input(m)],
		[966, func():
			check(Input.is_key_pressed(KEY_D) and current_scene.read_input().x > 0.0, "gamepad stick moves the player")
			var m := InputEventJoypadMotion.new()
			m.axis = JOY_AXIS_LEFT_X
			m.axis_value = 0.0
			root.push_input(m)
			_key(KEY_ESCAPE)],
		[968, func():
			check(launch._overlay != null and paused, "Esc opens pause overlay (offline pauses)")
			check(not Input.is_key_pressed(KEY_D), "stick released")
			_key(KEY_ESCAPE)],
		[970, func():
			check(launch._overlay == null and not paused, "Esc closes overlay")],
	]

func _physics_process(_dt: float) -> bool:
	frame += 1
	while not steps.is_empty() and frame >= steps[0][0]:
		var s = steps.pop_front()
		s[1].call()
	if steps.is_empty() or frame > 1200:
		for f in ["test_menu_settings.cfg"]:
			DirAccess.remove_absolute("user://" + f)
		print("MENU FLOW %s" % ("PASS" if ok and steps.is_empty() else "FAIL"))
		quit(0 if ok and steps.is_empty() else 1)
	return false
