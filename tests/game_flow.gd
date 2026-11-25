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
		[2, func(): _connect_listeners()],  # world/series are (re)built in main._ready -> connect after
		[5, func(): check(main.world.phase == main.World.Phase.PRESNAP, "starts presnap")],
		[6, func(): check(main.world.snap(), "snap")],
		[40, func(): check(main.world.ball.is_held_by(main.controlled_id), "QB has ball")],
		[41, func(): main.aim_point = Vector2(40, 45); main._set_charging(true)],
		[80, func(): check(main.charge > 0.3, "charge builds (%.2f)" % main.charge); check(main.arc_dots[0].visible, "arc preview shown")],
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
		[3210, func(): slant_wr = _ai_receiver(); slant_x = slant_wr.position.x; main.world.snap()],
		[3300, func(): check(absf(slant_wr.position.x - slant_x) > 2.0 and absf(slant_wr.position.x - main.field.width / 2.0) < absf(slant_x - main.field.width / 2.0), "AI WR broke inside on slant (dx %.1f)" % (slant_wr.position.x - slant_x)); check(main.route_mesh.get_surface_count() == 0, "route lines hidden after snap")],
		# A13: forced interception -> live return -> whistle -> possession flips
		[3301, func(): _force_dead_if_live(); main.series.start(0, 30.0); main.world.snap()],
		[3330, func(): main.ai.defense_enabled = false; _setup_pick()],  # CB holds the spot (bots would play man)
		[3331, func(): main.world.throw(main.world.find_role(0, main.Athlete.Role.QB).id, Vector2(50, 60), 0.9)],
		[3470, func(): check(picked, "interception happened"); check(main.hud.text.find("INTERCEPTION") >= 0, "HUD interception banner"); main.ai.defense_enabled = true],
		[4300, func(): _force_dead_if_live(); main.next_play(); check(main.world.offense_team == 1, "possession flipped after the pick (%s)" % main.series.last_outcome.get("outcome", "?"))],
		# A14: you're on defense vs a bot offense -> bots call a play and snap on their own
		[4301, func(): check(main.world.get_athlete(main.my_id).team != main.world.offense_team, "human on defense"); check(main.world.phase == main.World.Phase.PRESNAP, "presnap")],
		[4301 + int(60 * 2.5) + 10, func(): check(main.world.phase != main.World.Phase.PRESNAP, "bot offense snapped by itself")],
		# A15: rebuild as 3v3 in place
		[4500, func(): main.configure(3)],
		[4502, func(): check(main.world.athletes.size() == 6 and main.athlete_root.get_child_count() == 6, "3v3: 6 athletes + views"); check(absf(main.field.width - 30.0) < 0.01, "3v3 field width 30"); check(main.hud.text.find("3v3") >= 0, "HUD shows 3v3")],
		[4503, func(): var qb = main.world.find_role(0, main.Athlete.Role.QB); check(main.world.ball.is_held_by(qb.id), "3v3: QB starts with the ball"); check(main.world.snap(), "3v3 snap")],
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

func _connect_listeners() -> void:
	main.series.match_event.connect(func(_n, _d): series_events += 1)
	main.world.event.connect(func(n, d): if n == "catch": caught_by = d["by"])
	main.world.event.connect(func(n, d): if n == "tackle" and caught_by >= 0: tackled = true)
	main.world.event.connect(func(n, _d): if n == "interception": picked = true)

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

func _physics_process(_dt: float) -> bool:
	if steps.is_empty():  # _initialize failed: never hang
		print("GAME FLOW FAIL (setup error)")
		quit(1)
		return true
	frame += 1
	for s in steps:
		if s[0] == frame:
			s[1].call()
	if frame > steps[-1][0]:
		print("GAME FLOW " + ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false
