extends SceneTree
## Scripted end-to-end flow through the real main scene (presentation glue).
## Each step: [physics frame @60Hz, callable]. Exits 1 on failed check.

var main
var frame := 0
var ok := true
var steps: Array = []
var caught_by := -1
var tackled := false
var spot := 0.0
var series_events := 0
var before_id := -1
var slant_wr = null
var slant_x := 0.0
var picked := false
var xp0 := 0
var frozen_y := 0.0
var wr_id := -1

func check(cond: bool, msg: String) -> void:
	print(("  FLOW OK   " if cond else "  FLOW FAIL ") + msg)
	if not cond:
		ok = false

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.auto_next = false
	# scripted steps drive play changes; auto-advance checked at the end
	steps = [
		[2, func(): _connect_listeners(); _isolate_user_files()],  # world/series are (re)built in main._ready -> connect after
		[5, func(): check(main.world.phase == main.World.Phase.PRESNAP, "starts presnap")],
		[6, func(): check(main.world.snap(), "snap")],
		[40, func(): check(main.world.ball.is_held_by(main.controlled_id), "QB has ball")],
		[41, func(): main.aim_point = Vector2(40, 45); main._set_charging(true)],
		[80, func(): check(main.charge > 0.3, "charge builds (%.2f)" % main.charge); check(main.arc_shown(), "arc preview shown")],
		[81, func(): main._set_charging(false)],
		[82, func(): check(main.world.forward_pass_thrown, "pass thrown")],
		[400, func(): check(main.world.phase == main.World.Phase.DEAD, "incomplete ends play")],
		# A04: reset, snap, lead a pass to a WR running his go route -> catch + control switch
		[401, func(): main.next_play(); check(main.series.downs.down == 2, "incomplete -> 2nd down"); check(main.controlled_id == main.my_id, "control back to my athlete")],
		[402, func(): main.world.snap()],
		[480, func(): _lead_to_wr()],
		[481, func(): main._set_charging(true)],
		[530, func(): main._set_charging(false)],
		[531, func(): check(main.world.forward_pass_thrown, "lead pass thrown")],
		[800, func(): check(caught_by >= 0, "WR caught it"); check(main.controlled_id == caught_by, "control switched to receiver")],
		# A05: idle receiver gets run down by AI pursuit and tackled
		[1300, func(): check(tackled, "AI defender tackled the carrier"); check(main.world.phase == main.World.Phase.DEAD, "whistle: play dead"); check(main.last_whistle == "TACKLE", "HUD whistle reason")],
		# A07: next play at the tackle spot with correct down
		[1301, func(): spot = main.world.dead_ball_spot.y; main.next_play()],
		[1302, func(): check(absf(main.world.los_y - clampf(spot, 1, 99)) < 0.01, "LOS moved to tackle spot"); check(main.series.downs.down == 1 if spot >= 35.0 else main.series.downs.down == 3, "down advanced correctly (spot %.1f, %s)" % [spot, main.series.downs.label()]); check(main.hud.text.find(" & ") >= 0, "HUD shows down & distance")],
		[1303, func(): main.world.snap(); main.auto_next = true; series_events = 0],
		[2400, func(): check(series_events >= 1, "auto next play fired after whistle (%d)" % series_events)],
		# A08: forced touchdown -> score -> try -> kickoff
		[2401, func(): main.auto_next = false; main.series.start(0, 95.0); main.set_controlled(main.my_id)],
		[2402, func(): main.world.snap()],
		[2430, func(): var c = main.world.carrier(); c.position = Vector2(26, 101.0)],
		[2432, func(): check(main.last_whistle == "TOUCHDOWN", "touchdown whistle")],
		[2433, func(): main.next_play(); check(main.series.score[0] == 6, "home +6"); check(main.series.state == main.Match.State.TRY, "try state")],
		[2434, func(): check(main.hud.text.find("HOME 6") >= 0 and main.hud.text.find("TRY") >= 0, "HUD scoreboard + try")],
		[2435, func(): check(main.series.choose_try(2), "choose 2-pt try"); check(absf(main.world.los_y - 90.0) < 0.01, "2-pt from the 10")],
		[2436, func(): main.world.snap()],
		[2470, func(): var c = main.world.carrier(); c.position = Vector2(26, 101.0)],
		[2472, func(): main.next_play(); check(main.series.score[0] == 8, "try good: 8"); check(main.world.offense_team == 1 and absf(main.world.los_y - 25.0) < 0.01, "kickoff: away ball at its 25")],
		# A09: play clock auto-snap, untimed down, halftime
		[2473, func(): check(main.hud.text.find("H1 ") >= 0 and main.hud.text.find("PLAY ") >= 0, "HUD game + play clock"); main.series.clock.play_clock = 0.3],
		[2500, func(): check(main.world.phase == main.World.Phase.LIVE, "play clock auto-snapped"); main.series.clock.remaining = 0.2],
		[2530, func(): check(main.series.clock.expired(), "clock hit 0:00")],
		[3200, func(): _force_dead_if_live(); main.next_play(); check(main.series.clock.half == 2, "halftime -> 2nd half"); check(main.world.offense_team == 1 - main.series.opening_receiver, "other team receives 2nd half")],
		# A11: position change + team swap between plays, rejected while live
		[3201, func(): before_id = main.my_id; check(main.do_action({"a": "cycle"}), "TAB position change"); check(main.my_id != before_id and main.controlled_id == main.my_id, "now controlling new position")],
		[3202, func(): var t0: int = main.world.get_athlete(main.my_id).team; check(main.do_action({"a": "team"}), "team swap"); check(main.world.get_athlete(main.my_id).team == 1 - t0, "on the other team")],
		[3203, func(): check(main.hud.text.find("[TAB pos") >= 0, "HUD shows position")],
		[3204, func(): main.world.snap()],
		[3205, func(): check(not main.do_action({"a": "team"}), "no team swap during live play")],
		# A12: play call -> route art -> receivers run it
		[3206, func(): _force_dead_if_live(); main.series.start(0, 30.0); if main.world.get_athlete(main.my_id).team != 0: main.do_action({"a": "team"})],
		[3207, func(): check(main.do_action({"a": "play", "p": "Slants"}), "call Slants"); check(main.world.play_name == "Slants", "play set")],
		[3209, func(): check(main.route_mesh.get_surface_count() > 0, "route lines drawn presnap"); check(main.hud.text.find("PLAY: Slants") >= 0, "HUD shows play")],
		[3210, func(): main.ai.defense_enabled = false; slant_wr = _ai_receiver(); slant_x = slant_wr.position.x; main.world.snap()],  # route glue only (CB inside leverage takes slants away)
		[3300, func(): check(absf(slant_wr.position.x - slant_x) > 2.0 and absf(slant_wr.position.x - main.field.width / 2.0) < absf(slant_x - main.field.width / 2.0), "AI WR broke inside on slant (dx %.1f)" % (slant_wr.position.x - slant_x)); check(main.route_mesh.get_surface_count() == 0, "route lines hidden after snap"); main.ai.defense_enabled = true],
		# A13: forced interception -> live return -> whistle -> possession flips
		[3301, func(): _force_dead_if_live(); main.series.start(0, 30.0); main.world.snap()],
		[3330, func(): main.ai.defense_enabled = false; _setup_pick()],  # CB holds the spot (bots would play man)
		[3331, func(): main.world.throw(main.world.find_role(0, main.Athlete.Role.QB).id, Vector2(50, 60), 0.9)],
		[3470, func(): check(picked, "interception happened"); check(main.hud.text.find("INTERCEPTION") >= 0, "HUD interception banner"); main.ai.defense_enabled = true],
		[4170, func(): _force_dead_if_live(); main.next_play(); check(main.world.offense_team == 1, "possession flipped after the pick (%s)" % main.series.last_outcome.get("outcome", "?"))],
		# A14: you're on defense vs a bot offense -> bots call a play and snap on their own
		[4171, func(): check(main.world.get_athlete(main.my_id).team != main.world.offense_team, "human on defense"); check(main.world.phase == main.World.Phase.PRESNAP, "presnap")],
		[4172, func():
			var old: String = main.world.defensive_call
			check(main.huddle_remaining() > 0 and main.huddle_calls(main.world.get_athlete(main.my_id).team).contains("Cover"), "defensive huddle opens with coverage calls")
			_key(KEY_Q)
			check(main.world.defensive_call != old, "Q selects a defensive call through the real key handler")
			check(main.route_mesh.get_surface_count() == 1, "presnap defense assignment art is visible")
			_key(KEY_Y)
			check(main.huddle_remaining() == 0, "auto call dismisses the huddle")
			_key(KEY_Y)
			check(main.huddle_remaining() > 0, "manual calling restores the huddle")],
		[4171 + int(60 * 5.0) + 10, func(): check(main.world.phase != main.World.Phase.PRESNAP, "bot offense snapped by itself")],
		# A15: rebuild as 3v3 in place
		[4500, func(): main.configure(3)],
		[4502, func(): check(main.world.athletes.size() == 6 and main.athlete_root.get_child_count() == 6, "3v3: 6 athletes + views"); check(absf(main.field.width - 30.0) < 0.01, "3v3 field width 30"); check(main.hud.text.find("3v3") >= 0, "HUD shows 3v3")],
		[4503, func(): var qb = main.world.find_role(0, main.Athlete.Role.QB); check(main.world.ball.is_held_by(qb.id), "3v3: QB starts with the ball"); check(main.world.snap(), "3v3 snap")],
		# Real keyboard path (regression: handler had silently never been updated since iter 002)
		[4600, func(): main.configure(7)],
		[4602, func(): var p0: String = main.world.play_name; _key(KEY_Q); check(main.world.play_name != p0, "Q key calls next play (%s)" % main.world.play_name)],
		[4603, func(): before_id = main.my_id; _key(KEY_TAB); check(main.my_id != before_id, "TAB key changes position")],
		[4604, func(): var r0 = main.world.route_of.get(main.my_id, ""); _key(KEY_F); check(main.world.route_of.get(main.my_id, "") != r0 and r0 != "", "F key changes my route")],
		[4605, func(): var t0: int = main.world.get_athlete(main.my_id).team; _key(KEY_T); check(main.world.get_athlete(main.my_id).team == 1 - t0, "T key swaps team")],
		# C08d: on defense pre-snap, real Space breaks stance (no snap) and the barrier shows
		[4606, func(): var me = main.world.get_athlete(main.my_id); check(me.team != main.world.offense_team and main.world.phase == main.World.Phase.PRESNAP, "on defense presnap"); check(me.role == main.Athlete.Role.DL or me.set_lock, "defender starts in stance"); check(main.pres.barrier.visible, "LOS barrier visible presnap")],
		[4607, func(): var me = main.world.get_athlete(main.my_id); if me.role != main.Athlete.Role.DL: check(main.hud.text.find("break stance") >= 0, "HUD: Space to break stance"); _key(KEY_SPACE); check(main.world.phase == main.World.Phase.PRESNAP, "defense Space doesn't snap"); check(me.role == main.Athlete.Role.DL or not me.set_lock, "Space broke stance")],
		[4608, func(): _key(KEY_T); check(main.world.get_athlete(main.my_id).team == main.world.offense_team, "T again: back on offense")],
		[4609, func(): _key(KEY_SPACE); check(main.world.phase == main.World.Phase.LIVE, "Space key snaps")],
		# A17: practice drills through the real game
		[4700, func(): main.start_practice("passing"); check(main.drill != null and main.world.athletes.size() == 4, "passing drill: 4 athletes")],
		[4702, func(): check(main.hud.text.find("PRACTICE: Passing") >= 0, "HUD shows drill"); _key(KEY_SPACE)],
		[4703, func(): main.world.call_play("Verticals")],
		[4790, func(): _lead_to_wr(); main._set_charging(true)],
		[4840, func(): main._set_charging(false)],
		[5100, func(): check(main.drill.successes == 1 and main.drill.reps == 1, "drill counted the completion (%d/%d)" % [main.drill.successes, main.drill.reps])],
		[5200, func(): check(main.world.phase == main.World.Phase.PRESNAP and main.controlled_id == main.my_id, "rep reset to presnap, control back to QB")],
		[5300, func(): main.start_practice("tackling"); check(main.world.phase == main.World.Phase.LIVE, "tackling drill starts live")],
		[5301, func(): _chase_and_tackle()],
		[5800, func(): check(not _chasing, "tackling rep finished")],
		# A19: Chaosball through the real game
		[5900, func(): main.configure(7, "", "chaosball")],
		[5902, func(): check(main.world.is_chaos() and main.match_size == 3, "chaosball forces 3v3 + ruleset"); check(main.hud.text.find("CHAOSBALL") >= 0, "HUD shows CHAOSBALL"); _key(KEY_SPACE)],
		[5903, func(): main.ai.defense_enabled = false; var qb = main.world.get_athlete(main.my_id); qb.position.y = main.world.los_y + 6.0; main.aim_point = qb.position + Vector2(0, 8); main.lob_override = true; main._set_charging(true)],
		[5910, func(): main._set_charging(false); main.lob_override = null; check(main.world.forward_pass_thrown, "real throw past the LOS accepted (lob)"); main.ai.defense_enabled = true],
		# A20: streak HUD + pass clock explosion through the real game
		[6000, func(): main.configure(3, "", "chaosball"); main.ai.defense_enabled = false; main.ai.offense_enabled = false],
		[6002, func(): check(main.hud.text.find("STREAK 0 -> TD 2") >= 0, "HUD shows streak + TD value"); _key(KEY_SPACE)],
		[6002 + int(60 * 5.3), func(): check(main.last_whistle == "EXPLODE", "held too long: ball exploded (%s)" % main.last_whistle); main.ai.defense_enabled = true; main.ai.offense_enabled = true],
		# A21: stats from a real completion -> final whistle -> HUD summary
		[6400, func(): main.configure(7); main.ai.defense_enabled = false; main.world.call_play("Verticals")],
		[6401, func(): _key(KEY_SPACE)],
		[6480, func(): _lead_to_wr(); main._set_charging(true)],
		[6530, func(): main._set_charging(false)],
		[6799, func(): main.leaderboard_path = "user://test_flow_leaderboard.json"; DirAccess.remove_absolute(ProjectSettings.globalize_path(main.leaderboard_path))],
		[6800, func(): check(main.stats.total("att") >= 1 and main.stats.total("comp") >= 1, "stats tracked the completion (%d/%d)" % [main.stats.total("comp"), main.stats.total("att")]); _force_dead_if_live(); main.series.clock.half = 2; main.series.clock.remaining = 0.0; main.next_play(); main.ai.defense_enabled = true],
		[6802, func(): check(main.series.is_final(), "final"); check(main.hud.text.find("You QB: 1/1") >= 0, "HUD summary shows your QB line")],
		# A22: match recorded to the leaderboard file; HUD shows your rank
		[6803, func(): var lb = main.Leaderboard.new(); lb.load_file(main.leaderboard_path); check(lb.rank_of("You", "QB") == 1, "leaderboard file has You|QB at #1"); check(main.hud.text.find("YOUR RANKS: QB #1") >= 0, "HUD shows your rank"); DirAccess.remove_absolute(ProjectSettings.globalize_path(main.leaderboard_path))],
		# Post-game: players of the game picked at final -> presentation beats -> overview data
		[6804, func(): check(main.potg.size() >= 2 and main.potg.size() <= 4, "2-4 players of the game (%d)" % main.potg.size()); check(main.potg[0]["title"] == "PLAYER OF THE GAME" and main.potg.any(func(e): return e["name"] == "You"), "your QB line made the cut"); check(main.postgame_t >= 0.0 and main.postgame == null, "presentation queued after the FINAL hold"); main.start_postgame()],
		[6806, func(): var st = main.postgame; check(st != null and st.views.size() == main.potg.size() and st.step == -1, "presentation intro with one athlete per pick"); st.advance(); check(st.step == 0 and st.cards[0].visible, "first spotlight card")],
		[6810, func(): var st = main.postgame; st.skip(); check(st.is_done() and main.postgame_done and main.postgame == null, "skip ends the presentation"); var ov = main.match_overview(); check(ov["potg"].size() == main.potg.size() and ov["teams"].size() == 2 and ov["my_lines"].size() >= 1, "overview carries picks, team stats, your line %s" % str(ov["my_lines"]))],
		# A23: ranked match vs a human rival -> rating change saved + on HUD
		[6900, func(): main.configure(7); _setup_ranked_rival()],
		[6902, func(): main.series.score = [7, 0]; main.series.clock.half = 2; main.series.clock.remaining = 0.0; main.world.phase = main.World.Phase.DEAD; main.series.last_result = {"type": "incomplete"}; main.next_play()],
		[6904, func(): var rk = main.Ranked.new(); rk.load_file(main.ranked_path); check(rk.rating("You") > 1000.0 and rk.rating("Rival") < 1000.0, "ratings saved (You %.0f, Rival %.0f)" % [rk.rating("You"), rk.rating("Rival")]); check(main.hud.text.find("RATING ") >= 0 and main.hud.text.find("(+24)") >= 0, "HUD shows rating change"); DirAccess.remove_absolute(ProjectSettings.globalize_path(main.ranked_path)); DirAccess.remove_absolute(ProjectSettings.globalize_path(main.leaderboard_path))],
		# A24: earned cosmetics on your athlete, TD celebration, XP at final
		[7000, func(): main.profile.xp = 600; check(main.profile.equip("trim", "ember") and main.profile.equip("celebration", "spin") and main.profile.equip("number", 88), "equip earned items (level 1)"); check(not main.profile.equip("trim", "aurora"), "locked item refused"); main.configure(7)],
		[7002, func(): var v = main.views[main.my_id]; check(v.number_text == "88" and v.trim_color.is_equal_approx(main.Cosmetics.color_of("trim", "ember")), "your look shown on your athlete"); check(main.views[(main.my_id + 1) % main.views.size()].number_text != "88", "others keep their own looks")],
		[7003, func(): _key(KEY_SPACE)],
		[7030, func(): main.world.carrier().position = Vector2(26, 101.0)],
		[7032, func(): check(main.views[main.my_id].is_celebrating(), "TD celebration plays")],
		[7033, func(): xp0 = main.profile.xp; main.next_play(); main.series.clock.half = 2; main.series.clock.remaining = 0.0; main.world.phase = main.World.Phase.DEAD; main.series.last_result = {"type": "incomplete"}; main.next_play()],
		[7035, func(): check(main.profile.xp > xp0 and main.hud.text.find("XP +") >= 0, "XP awarded at final (%d -> %d)" % [xp0, main.profile.xp]); var saved = main.Cosmetics.new(); saved.load_file(main.profile_path); check(saved.xp == main.profile.xp, "XP saved to (temp) profile"); DirAccess.remove_absolute(ProjectSettings.globalize_path(main.profile_path))],
		# A25: instant replay with the real V key, saved replay, viewer
		[7100, func(): main.replay_dir = "user://test_flow_replays"; main.configure(7); main.ai.defense_enabled = false],
		[7101, func(): _key(KEY_SPACE)],
		[7200, func(): main.world.carrier().position = Vector2(26, 101.0)],
		[7203, func(): check(main.world.phase == main.World.Phase.DEAD, "play over"); frozen_y = main.world.athletes[0].position.y; _key(KEY_V); check(main.replay_active, "V starts instant replay")],
		[7210, func(): var p = main.replay.last_play(); var smp = main.replay.sample(); var rp = Vector3(smp["pos"][3].x, 0, -smp["pos"][3].y); check(main.views[3].target_position().distance_to(rp) < 0.01, "views show replay frames"); check(main.views[3].position.distance_to(rp) < 0.5, "drawn view within one interpolation step of the replay frame"); check(main.hud.text.find("REPLAY 0.5x") >= 0, "HUD shows replay"); check(absf(main.world.athletes[0].position.y - frozen_y) < 0.001 and main.world.phase == main.World.Phase.DEAD, "offline sim frozen during replay")],
		[7500, func(): check(not main.replay_active, "replay ends -> back to live"); main.ai.defense_enabled = true],
		[7501, func(): main.series.clock.half = 2; main.series.clock.remaining = 0.0; main.series.last_result = {"type": "incomplete"}; main.next_play()],
		[7502, func(): check(main.saved_replay != "" and FileAccess.file_exists(main.saved_replay), "replay saved at final (%s)" % main.saved_replay)],
		[7503, func(): check(main.open_replay(main.saved_replay) and main.replay_viewer and main.replay.plays.size() >= 1, "viewer opens the saved replay"); _key(KEY_BRACKETRIGHT); check(main.replay.speed == 2.0, "] speeds up")],
		[7504, func(): _key(KEY_V); check(not main.replay_active, "V exits viewer"); for f in DirAccess.get_files_at(ProjectSettings.globalize_path("user://test_flow_replays")): DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_flow_replays/" + f))],
		# D04: achievements unlocked by a real TD + win, saved to the (temp) profile
		[7600, func(): main.profile.achievements = []; main.profile.games = 0; main.configure(7); main.ai.defense_enabled = false],
		[7601, func(): _key(KEY_SPACE)],
		[7630, func(): main.world.carrier().position = Vector2(26, 101.0)],
		[7632, func(): main.next_play(); main.world.snap(); main.series.last_result = {"type": "touchdown", "team": 0}; main.world.phase = main.World.Phase.DEAD; main.series.clock.half = 2; main.series.clock.remaining = 0.0; main.next_play()],
		[7634, func(): check(main.series.is_final(), "final"); check(main.profile.achievements.has("first_td") and main.profile.achievements.has("first_win"), "First Touchdown + First Win unlocked (%s)" % str(main.profile.achievements)); check(main.hud.text.find("ACHIEVEMENTS: ") >= 0, "HUD lists achievements"); var saved = main.Cosmetics.new(); saved.load_file(main.profile_path); check(saved.achievements.has("first_win"), "achievements saved"); main.ai.defense_enabled = true; DirAccess.remove_absolute(ProjectSettings.globalize_path(main.profile_path))],
		# C01: call a run, snap, exchange through G, then steer the RB.
		[7710, func():
			main.configure(7)
			main.ai.defense_enabled = false
			for i in 4: _key(KEY_Q)
			check(main.world.play_name == "Inside Zone", "Q selects a run play")
			_key(KEY_Q)
			_key(KEY_X)
			check(main.world.play_name == "Outside Sweep" and main.world.run_flipped, "Q selects the sweep and X flips it")],
		[7712, func():
			check(main.huddle_calls(0).contains("[Outside Sweep]") and main.route_mesh.get_surface_count() > 0, "huddle and turf show the selected run")
			_key(KEY_SPACE)],
		[7764, func():
			check(main.handoff_hint() == "G HANDOFF", "handoff prompt appears in reach")
			_key(KEY_G)
			var back = main.world.find_role(0, main.Athlete.Role.RB)
			check(main.world.carrier() == back and main.controlled_id == back.id, "G hands off and hands offline control to the back")
			main.input_override = Vector2.DOWN],
		[7766, func():
			check(main.pres.overlay.me_name.text.contains("YOU  RB/"), "HUD identifies the new controlled role")],
		[7830, func():
			check(main.world.carrier().position.y > main.world.los_y and main.world.phase == main.World.Phase.LIVE, "human RB runs across the LOS and stays live")
			var back = main.world.carrier()
			back.position.x = -0.5
			main.input_override = Vector2.ZERO],
		[7832, func():
			check(main.world.phase == main.World.Phase.DEAD and main.stats.total("car") == 1 and main.stats.total("rush_yds") > 0.0, "whistle records the RB's rushing attempt and gain")],
		# C04a: U from dead ball, then the one-minute warning at the next whistle.
		[7850, func():
			main.configure(3)
			main.ai.defense_enabled = false
			main.series.clock.remaining = 60.1
			_key(KEY_U)
			check(main.series.clock.timeouts == [1, 2], "U spends a timeout in 3v3")
			check(main.pres.overlay.banner.text == "TIMEOUT", "timeout banner appears")
			_key(KEY_SPACE)],
		[7870, func():
			check(main.world.phase == main.World.Phase.LIVE and main.series.clock.remaining < 60.0, "play stays live below 1:00")
			check(not main.pres.overlay.banner.visible, "timeout banner clears on the snap")
			check(main.pres.overlay.timeout_pips[0].is_visible_in_tree() and main.pres.overlay.timeout_pips[0].text == "●○", "live scorebug shows remaining timeouts")
			_key(KEY_U)
			check(main.series.clock.timeouts == [1, 2], "U cannot call timeout during the play")
			main.world.carrier().position.x = -0.5],
		[7874, func():
			check(main.world.phase == main.World.Phase.DEAD and main.pres.overlay.banner.text == "ONE-MINUTE WARNING", "warning appears after the whistle")],
	]

## First receiver not controlled by the human (humans don't auto-run routes).
func _ai_receiver():
	for r in main.world.receivers_in_order():
		if r.id != main.controlled_id and r.role == main.Athlete.Role.WR:
			return r
	return null

## Put an opposing CB alone at the throw spot; everyone else well away from it.
func _setup_pick() -> void:
	var cb = main.world.find_role(1, main.Athlete.Role.CB)
	for a in main.world.athletes:
		if a.id != cb.id and a.position.distance_to(Vector2(50, 60)) < 6.0:
			a.position.x = 30.0
	cb.position = Vector2(50, 60)

## Tackling drill: run at the carrier; press the real E key when in range.
var _chasing := false
func _chase_and_tackle() -> void:
	_chasing = true

func _chase_tick() -> void:
	if not _chasing or main.drill == null:
		return
	var me = main.world.get_athlete(main.my_id)
	var c = main.world.carrier()
	if c == null or main.drill.rep_over:
		_chasing = false
		main.input_override = null
		main.sprint_override = null
		check(main.drill.successes == 1, "tackled with the real E key (%d/%d)" % [main.drill.successes, main.drill.reps])
		return
	var to: Vector2 = c.position + c.velocity * 0.25 - me.position
	main.input_override = to.normalized()
	main.sprint_override = true
	if to.length() < 1.8 and me.can_act():
		me.facing = (c.position - me.position).normalized()
		_key(KEY_E)

## Inject a real key press through main's key handler.
func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	main._unhandled_key_input(ev)

## Never touch the player's real profile / leaderboard / ratings from tests.
func _isolate_user_files() -> void:
	main.profile_path = "user://test_flow_profile.json"
	main.leaderboard_path = "user://test_flow_leaderboard.json"
	main.ranked_path = "user://test_flow_ranked.json"
	main.replay_dir = "user://test_flow_replays"   # every final saves a replay; never into the real replays/
	for p in [main.profile_path, main.leaderboard_path, main.ranked_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	main.profile.load_file(main.profile_path)

func _connect_listeners() -> void:
	main.series.match_event.connect(func(_n, _d): series_events += 1)
	main.world.event.connect(func(n, d): if n == "catch": caught_by = d["by"])
	main.world.event.connect(func(n, d): if n == "tackle" and caught_by >= 0: tackled = true)
	main.world.event.connect(func(n, _d): if n == "interception": picked = true)

func _setup_ranked_rival() -> void:
	main.ranked_match = true
	main.ranked_path = "user://test_flow_ranked.json"
	main.leaderboard_path = "user://test_flow_leaderboard.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.ranked_path))
	main.lobby.players[99] = {"name": "Rival", "ready": true}
	main.roster.auto_assign_team(99, 1 - main.world.get_athlete(main.my_id).team)

func _force_dead_if_live() -> void:
	if main.world.phase != main.World.Phase.DEAD:
		main.series.last_result = {"type": "incomplete"}
		main.world.phase = main.World.Phase.DEAD

func _lead_to_wr() -> void:
	var qb = main.world.find_role(0, main.Athlete.Role.QB)
	var wr = main.world.find_role(0, main.Athlete.Role.WR)
	var from: Vector3 = Vector3(qb.position.x, qb.position.y, main.T.RELEASE_HEIGHT)
	# charge ~50 frames ≈ 0.83s of 0.9s -> power ~0.92; lead with that power
	var p: float = 50.0 / 60.0 / main.T.THROW_CHARGE_TIME
	var t_extra := 50.0 / 60.0  # WR keeps running while QB charges
	main.aim_point = main.Passing.lead_target(from, wr.position + wr.velocity * t_extra, wr.velocity, p)

var _sorted := false
func _physics_process(_dt: float) -> bool:
	if not _sorted and not steps.is_empty():
		steps.sort_custom(func(a, b): return a[0] < b[0])   # out-of-order steps once silently never ran
		_sorted = true
	if steps.is_empty():  # _initialize failed: never hang
		print("GAME FLOW FAIL (setup error)")
		quit(1)
		return true
	frame += 1
	_chase_tick()
	for s in steps:
		if s[0] == frame:
			s[1].call()
	if frame > steps[-1][0]:
		print("GAME FLOW " + ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false
