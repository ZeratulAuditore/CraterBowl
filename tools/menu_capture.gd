extends SceneTree
## Screenshot every main-menu screen (run under Xvfb like shot.sh):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --display-driver x11 --rendering-driver opengl3 \
##     --audio-driver Dummy --resolution 1280x720 -s res://tools/menu_capture.gd -- --out=/tmp/menu --settings-file=user://test_cap_settings.cfg
const SCREENS := ["welcome", "online", "bots", "practice", "locker", "leaders", "replays", "settings"]
var out := "/tmp/menu"
var menu
var frame := 0
var i := -1

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)

func _process(_dt: float) -> bool:
	frame += 1
	if frame == 2:
		var launch = root.get_node("Launch")
		launch.settings = launch.SettingsStore.new()
		launch.settings.upnp = false
		menu = load("res://scenes/menu.tscn").instantiate()
		menu.set_meta("force_menu", true)
		menu.profile_path = "user://test_cap_profile.json"
		menu.leaderboard_path = "user://test_cap_lb.json"
		menu.ranked_path = "user://test_cap_ranked.json"
		menu.replay_dir = "user://test_cap_replays"
		root.add_child(menu)
	if frame > 10 and frame % 20 == 0:
		if i >= 0:
			var img := root.get_texture().get_image()
			var p := "%s_%s.png" % [out, SCREENS[i]]
			print("SHOT %s (%s)" % [p, error_string(img.save_png(p))])
		i += 1
		if i >= SCREENS.size():
			DirAccess.remove_absolute("user://test_cap_settings.cfg")
			quit()
			return true
		if SCREENS[i] != "welcome":
			menu.launch.settings.player_name = "Ace"
		menu.current = ""
		menu.show_screen(SCREENS[i])
	return false
