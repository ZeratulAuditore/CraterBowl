extends "res://tests/visual/harness.gd"
## #67: kicking stats in the post-game. The local player (HELIOS QB, the kicker) makes 2 of 3
## field goals (long 47), kicks a PAT and punts once for 44 yards; a NEBULA bot returns a
## kickoff 27 yards. The real match_overview() then opens the lobby's game overview.

const Athlete := preload("res://src/sim/athlete.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var launch = root.get_node("Launch")
	launch.settings_path = "user://test_kicking_stats_settings.cfg"   # never leak the name into later cases
	launch.settings.player_name = "Ace"
	var game = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.auto_next = false
	game.opening_kickoff = false
	game.player_name = "Ace"
	var series = game.series
	series.start(0, 40.0)   # HELIOS (Ace) has the ball
	game.set_controlled(game.my_id)
	await _refresh()
	var w = game.world
	var me = w.get_athlete(game.my_id)
	check(me.team == 0 and w.offense_team == 0, "Ace is on offense")
	var los: float = w.los_y
	# Field goals: good from 47 and 33, wide from 52.
	for fg in [[47.0, true], [33.0, true], [52.0, false]]:
		w.event.emit("snap", {"qb": me.id})
		w.event.emit("kick", {"by": me.id, "kind": "fg", "power": 0.8, "target": Vector2(26, 110)})
		w.event.emit("field_goal", {"good": fg[1], "distance": fg[0], "spot": Vector2(26, 110), "team": 0, "kind": "fg"})
	# A PAT on the try.
	series.state = series.State.TRY
	w.event.emit("snap", {"qb": me.id})
	w.event.emit("kick", {"by": me.id, "kind": "fg", "power": 0.8, "target": Vector2(26, 110)})
	w.event.emit("field_goal", {"good": true, "distance": 25.0, "spot": Vector2(26, 110), "team": 0, "kind": "fg"})
	series.state = series.State.SCRIMMAGE
	# A punt from the LOS that rolls dead 44 yards downfield.
	w.event.emit("snap", {"qb": me.id})
	w.event.emit("kick", {"by": me.id, "kind": "punt", "power": 0.7, "target": Vector2(26, los + 40.0)})
	w.event.emit("kick_downed", {"spot": Vector2(26, los + 44.0), "team": 0, "kind": "punt"})
	# A kickoff: NEBULA's safety fields it at the HELIOS 95 and is tackled at the 68 (27 yd).
	var s = w.find_role(1, Athlete.Role.S)
	var wr = w.find_role(0, Athlete.Role.WR)
	w.event.emit("snap", {"qb": me.id})
	w.event.emit("kick", {"by": me.id, "kind": "kickoff", "power": 0.85, "target": Vector2(26, 95)})
	w.event.emit("kick_catch", {"by": s.id, "team": 1, "at": Vector2(26, 95)})
	w.event.emit("tackle", {"by": wr.id, "carrier": s.id, "spot": Vector2(24, 68), "team": 1})

	var me_line: Dictionary = game.stats.get_line("Ace", game.stats.ROLE[me.role])
	check(int(me_line.get("fg_made", 0)) == 2 and int(me_line.get("fg_att", 0)) == 3, "Ace 2/3 FG (%s/%s)" % [me_line.get("fg_made"), me_line.get("fg_att")])
	check(is_equal_approx(me_line.get("fg_long", 0.0), 47.0), "long 47 (%s)" % me_line.get("fg_long"))
	check(int(me_line.get("xp_made", 0)) == 1 and int(me_line.get("xp_att", 0)) == 1, "PAT is 1/1 XP, not an FG")
	check(int(me_line.get("punts", 0)) == 1 and is_equal_approx(me_line.get("punt_yds", 0.0), 44.0), "one 44-yard punt")
	check(is_equal_approx(game.stats.total("kr_yds"), 27.0), "bot credited a 27-yard kick return")
	# What the final whistle does in main.gd, then the hand-off to the lobby overview.
	game.summary_lines = game.stats.summary_lines()
	game.potg = game._decorate_potg(game.Potg.pick(game.stats.athletes, series.winner()))
	game.team_totals = game.Potg.team_totals(game.stats.athletes)
	var ov: Dictionary = game.match_overview()
	var want := "2/3 FG long 47, 1/1 XP, 1 punt 44.0 avg"
	check(ov["my_lines"].any(func(l): return str(l).contains(want)), "Ace's post-game line shows kicking: %s" % str(ov["my_lines"]))
	check(ov["potg"].any(func(e): return "   ".join(e["lines"]).contains("2/3 FG  LONG 47")), "players-of-the-game card shows it")
	launch.go_to_menu("", ov)
	for frame in 30:
		await process_frame
	var menu = current_scene
	check(menu != null and menu.scene_file_path == launch.MENU_SCENE and menu.current == "overview", "lobby opens the game overview")
	var view = menu.content.find_child("GameOverview", true, false)
	var shown := []
	if view:
		for l in view.find_children("*", "Label", true, false):
			shown.append(l.text)
	var txt := "\n".join(shown)
	check(txt.contains(want), "overview 'Your game' shows the kicking line")
	check(txt.contains("2/3 FG  LONG 47"), "overview player card shows FG made/att + long")
	await _refresh()
	await capture("kicking-stats-overview")
	# Scroll down to "Your game", the local player's own stat line.
	var mine: Control = null
	for l in view.find_children("*", "Label", true, false) if view else []:
		if l.text.contains("XP") or l.text.contains("FG long"):
			mine = l
	if mine:
		menu.content_scroll.ensure_control_visible(mine)
	await _refresh()
	check(mine != null and menu.content_scroll.get_global_rect().encloses(mine.get_global_rect()), "'Your game' line is on screen")
	await capture("kicking-stats-your-game")
	finish()

func _refresh() -> void:
	for frame in 5:
		await process_frame
