extends "res://tests/visual/harness.gd"
## #115: the last game's Team stats fit while the overview scrollbar is visible.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var launch = root.get_node("Launch")
	launch.settings.player_name = "Ace"
	launch.go_to_menu("", {
		"score": [21, 14], "winner": 0, "my_team": 0, "team_names": ["HELIOS", "NEBULA"],
		"mode": "classic", "size": 5,
		"my_lines": ["QB: 12/18 160yd 2TD 0INT", "RUSH: 4 CAR 40 YDS"], "xp": "XP +120 (Level 2)",
		"teams": [{"pass_yds": 160, "rush_yds": 40, "td": 3, "turnovers": 0, "sack": 1, "tkl": 12},
			{"pass_yds": 190, "rush_yds": 70, "td": 2, "turnovers": 1, "sack": 2, "tkl": 14}],
		"potg": [{"team": 0, "pos": "QB", "name": "Ace", "number": 12,
			"title": "PLAYER OF THE GAME", "lines": ["12/18 160 YDS 2 TD"]},
			{"team": 1, "pos": "LB", "name": "CPU", "number": 44,
				"title": "DEFENSIVE STANDOUT", "lines": ["7 TKL 1 SACK"]}],
	})
	await _frames(5)
	var menu = current_scene
	check(menu != null and menu.scene_file_path == launch.MENU_SCENE and menu.current == "overview",
		"return to the lobby opens the game overview")
	if menu == null or menu.scene_file_path != launch.MENU_SCENE:
		finish()
		return
	_settle_lobby(menu.lobby)
	for animation in menu.lobby.find_children("*", "AnimationPlayer", true, false):
		if animation.is_playing():
			animation.seek(0.0, true)
			animation.pause()
	menu.music.set_process(false)
	menu.music.player.stop()
	menu.music._process(0.0)
	var grid := menu.content.find_child("BoxScore", true, false) as GridContainer
	if grid == null:
		check(false, "team box score exists")
		finish()
		return
	var scroll: ScrollContainer = menu.content_scroll
	scroll.ensure_control_visible(grid)
	await _frames(3)
	var scrollbar := scroll.get_v_scroll_bar()
	check(scrollbar.visible and scroll.scroll_vertical > 0, "team stats visible after scrolling")
	check(scroll.get_global_rect().encloses(grid.get_global_rect()), "all team stats rows fit in the viewport")

	var helios := PackedStringArray()
	var nebula := PackedStringArray()
	var clearance := INF
	for row in 7:
		var left := grid.get_child(row * 3 + 1) as Label
		var right := grid.get_child(row * 3 + 2) as Label
		helios.append(left.text)
		nebula.append(right.text)
		clearance = minf(clearance, scrollbar.get_global_rect().position.x - right.get_global_rect().end.x)
	check(helios == PackedStringArray(["HELIOS", "160", "40", "3", "0", "1", "12"]), "HELIOS heading and six values")
	check(nebula == PackedStringArray(["NEBULA", "190", "70", "2", "1", "2", "14"]), "NEBULA heading and six values")
	check(clearance >= 8.0, "minimum NEBULA clearance from the scrollbar is %.1f px" % clearance)
	await capture("team-stats-scrolled")

	menu.show_screen("home")
	_settle_lobby(menu.lobby)
	await capture("home")
	finish()

func _settle_lobby(lobby) -> void:
	lobby.set_process(false)
	lobby._t = 0.0
	lobby._shift = lobby._shift_to
	lobby._process(0.0)

func _frames(count: int) -> void:
	for frame in count:
		await process_frame
