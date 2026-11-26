extends SceneTree
## Screenshot the post-game flow with sample data (run under Xvfb like menu_capture.gd):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --display-driver x11 --rendering-driver opengl3 \
##     --audio-driver Dummy --resolution 1280x720 -s res://tools/potg_capture.gd -- --out=/tmp/potg --settings-file=user://test_cap_settings.cfg
## Shots: intro, each spotlight, group shot (PotgStage), then the lobby's game overview.
const PotgStage := preload("res://src/ui/potg_stage.gd")
const SAMPLE := [
	{"id": 3, "team": 0, "pos": "QB", "name": "Ace", "number": 12, "title": "PLAYER OF THE GAME", "lines": ["18/24  246 YDS  3 TD", "4 CAR  31 YDS"]},
	{"id": 11, "team": 0, "pos": "WR", "name": "CPU", "number": 81, "title": "TOP RECEIVER", "lines": ["7 REC  128 YDS  2 TD"]},
	{"id": 19, "team": 1, "pos": "LB", "name": "Rival", "number": 54, "title": "DEFENSIVE STANDOUT", "lines": ["9 TKL  2 SACK  1 INT"]},
	{"id": 6, "team": 1, "pos": "RB", "name": "CPU", "number": 22, "title": "TOP RUSHER", "lines": ["14 CAR  97 YDS  1 TD"]}]
const COLORS := [Color(0.95, 0.75, 0.15), Color(0.3, 0.8, 0.95)]
var out := "/tmp/potg"
var stage
var menu
var frame := 0
var shots := []   # [frame, name, callable before shot]

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)

func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	var p := "%s_%s.png" % [out, name]
	print("SHOT %s (%s)" % [p, error_string(img.save_png(p))])

func _process(_dt: float) -> bool:
	frame += 1
	if frame == 2:
		stage = PotgStage.new()
		stage.setup(SAMPLE, {"score": [28, 17], "winner": 0, "team_colors": COLORS, "team_names": ["HELIOS", "NEBULA"]})
		stage.set_process(false)   # beats driven below (software GL is too slow for real time)
		root.add_child(stage)
	if stage and frame > 2 and frame < 400:
		stage._process(1.0 / 30.0)   # deterministic clock
		stage.step_t = minf(stage.step_t, 1.2)   # hold each beat until we advance it
	match frame:
		40: _shot("0_intro"); stage.advance()
		80: _shot("1_spot0"); stage.advance()
		120: _shot("2_spot1"); stage.advance()
		160: _shot("3_spot2"); stage.advance()
		200: _shot("4_spot3"); stage.advance()
		260: _shot("5_group"); stage.queue_free(); stage = null
		262:
			var launch = root.get_node("Launch")
			launch.settings = launch.SettingsStore.new()
			launch.settings.upnp = false
			launch.settings.player_name = "Ace"
			launch.last_match = {"score": [28, 17], "winner": 0, "my_team": 0, "team_names": ["HELIOS", "NEBULA"],
				"mode": "classic", "size": 5, "online": true, "me": "Ace", "potg": SAMPLE,
				"teams": [{"pass_yds": 246, "rush_yds": 88, "td": 4, "turnovers": 0, "tkl": 21, "sack": 1},
					{"pass_yds": 173, "rush_yds": 121, "td": 2, "turnovers": 2, "tkl": 26, "sack": 3}],
				"my_lines": ["QB: 18/24 246yd 3TD 0INT | 4 car 31yd 0TD"], "xp": "XP +185 (Level 4 - LEVEL UP!)",
				"achievements": "ACHIEVEMENTS: First Win", "ranks": "QB #2"}
			menu = load("res://scenes/menu.tscn").instantiate()
			menu.set_meta("force_menu", true)
			menu.profile_path = "user://test_cap_profile.json"
			menu.leaderboard_path = "user://test_cap_lb.json"
			menu.ranked_path = "user://test_cap_ranked.json"
			menu.replay_dir = "user://test_cap_replays"
			root.add_child(menu)
		320:
			_shot("6_overview")
			DirAccess.remove_absolute("user://test_cap_settings.cfg")
			quit()
			return true
	return false
