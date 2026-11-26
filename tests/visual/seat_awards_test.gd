extends "res://tests/visual/harness.gd"
## #156: a shared display name doesn't share the postgame win and touchdown awards.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.auto_next = false
	await process_frame
	game.player_name = "Ann"
	game.profile = game.Cosmetics.new()
	game.profile_path = "user://test_seat_awards_profile.json"
	game.leaderboard_path = "user://test_seat_awards_leaderboard.json"
	game.replay_dir = "user://test_seat_awards_replays"
	game.lobby.players[99] = {"name": "Ann", "ready": true}
	var rival: int = game.roster.auto_assign_team(99, 1)
	check(rival >= 0 and game.owner_name(rival) == game.owner_name(game.my_id),
		"opponents share a display name")
	game.series.start(0, 95.0)
	game.world.event.emit("snap", {"qb": game.my_id})
	game.world.event.emit("touchdown", {"carrier": game.my_id, "spot": Vector2(26, 100), "team": 0, "points": 6})
	game.series.score = [6, 0]
	game.series.clock.half = 2
	game.series.clock.remaining = 0.0
	game.world.phase = game.World.Phase.DEAD
	game.series.last_result = {"type": "incomplete"}
	game.next_play()
	check(game.profile.xp == 375 and game.profile.games == 1, "winner earns 375 XP (%d)" % game.profile.xp)
	check(game.profile.achievements.has("first_td") and game.profile.achievements.has("first_win"),
		"winner earns First Touchdown and First Win")

	var launch = root.get_node("Launch")
	launch.settings.player_name = "Ann"
	launch.go_to_menu("", game.match_overview())
	for frame in 5:
		await process_frame
	var menu = current_scene
	var awards: Label = null
	var achievements: Label = null
	if menu != null and menu.scene_file_path == launch.MENU_SCENE:
		for label in menu.content.find_children("*", "Label", true, false):
			if label.text.begins_with("XP +"):
				awards = label
			elif label.text.begins_with("ACHIEVEMENTS:"):
				achievements = label
	check(awards != null and awards.text.begins_with("XP +375"), "overview displays the winner's own award")
	check(achievements != null and achievements.text.contains("First Touchdown, First Win"),
		"overview displays both of the winner's achievements")
	if awards != null:
		menu.content_scroll.ensure_control_visible(achievements if achievements != null else awards)
		await process_frame
		await process_frame
		menu.lobby.set_process(false)
		menu.lobby._t = 0.0
		menu.lobby._shift = menu.lobby._shift_to
		menu.lobby._process(0.0)
		for animation in menu.lobby.find_children("*", "AnimationPlayer", true, false):
			if animation.is_playing():
				animation.seek(0.0, true)
				animation.pause()
		menu.music.set_process(false)
		menu.music.player.stop()
		menu.music._process(0.0)
		await capture("winner-overview")
	finish()
