extends Node3D
## Builds the field, spawns the local player and camera. Presentation only:
## rules live in src/sim. Sim (x, y) yards maps to 3D (x, 0, -y).

const World := preload("res://src/sim/world.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const PlayerNode := preload("res://src/game/player.gd")
const Passing := preload("res://src/sim/passing.gd")
const AI := preload("res://src/sim/ai.gd")
const Match := preload("res://src/sim/match.gd")
const NEXT_PLAY_DELAY := 2.0
const NetSession := preload("res://src/net/net_session.gd")
const Protocol := preload("res://src/net/protocol.gd")
const SNAPSHOT_EVERY := 2   # physics ticks (60 Hz -> 30 Hz snapshots)
const Predictor := preload("res://src/net/client_predictor.gd")
const Interp := preload("res://src/net/interpolator.gd")
const INTERP_DELAY := 0.1   # seconds others render in the past
const Roster := preload("res://src/sim/roster.gd")
const LOCAL_PLAYER := 1      # the local human's player id (= host peer id online)
const Routes := preload("res://src/sim/routes.gd")
const Controls := preload("res://src/ui/controls.gd")
const MatchConfig := preload("res://src/sim/match_config.gd")
const Lobby := preload("res://src/net/lobby.gd")
const Drills := preload("res://src/sim/drills.gd")
const Stats := preload("res://src/sim/stats.gd")
const Leaderboard := preload("res://src/sim/leaderboard.gd")
const Ranked := preload("res://src/sim/ranked.gd")
const Cosmetics := preload("res://src/sim/cosmetics.gd")
const Replay := preload("res://src/sim/replay.gd")
const Achievements := preload("res://src/sim/achievements.gd")
const MMServer := preload("res://src/net/mm_server.gd")
const MMClient := preload("res://src/net/mm_client.gd")
const InviteCode := preload("res://src/net/invite_code.gd")
const T := preload("res://src/sim/tuning.gd")
const Presentation := preload("res://src/game/presentation.gd")
const Potg := preload("res://src/sim/potg.gd")
const PotgStage := preload("res://src/ui/potg_stage.gd")
const POSTGAME_HOLD := 3.0      # seconds on the FINAL scoreboard before players of the game
const FieldArt := preload("res://src/game/art/field_art.gd")
const StadiumArt := preload("res://src/game/art/stadium.gd")
const ArtMats := preload("res://src/game/art/materials.gd")
const ArtQuality := preload("res://src/game/art/quality.gd")
const TrainingArt := preload("res://src/game/art/training_art.gd")
const ARC_DOTS := 24

const TEAM_COLORS := [Color(0.95, 0.75, 0.15), Color(0.3, 0.8, 0.95)]

var world := World.new()
const Field := preload("res://src/sim/field.gd")
var field: Field = world.field
var controlled_id := -1
var views: Array = []
var player: Node3D  # view of the controlled athlete
var ball_view: MeshInstance3D
var reticle: MeshInstance3D
var arc_dots: Array = []
# Render interpolation for the ball (views interpolate themselves; see player.gd).
var _ball_prev := Vector3.ZERO
var _ball_cur := Vector3.ZERO
var _route_key := 0          # last drawn route-art state; rebuild only when it changes
var charging := false
var charge := 0.0
var aim_point := Vector2(26, 45)
var ai := AI.new()
var last_whistle := ""
var banner := ""
var banner_t := 0.0
var series: Match
var roster := Roster.new()
var match_size := 7
var match_mode := "classic"     # classic | chaosball
var lobby := Lobby.new()      # server: authoritative; client: mirror
var debug_playclock := -1.0
var drill: Drills = null        # offline practice drill (null = normal match)
var training_path := Drills.DEFAULT_BESTS_PATH   # personal bests (tests pass --training-file)
var queue_started_ms := 0       # matchmaking: when we queued (warm-up HUD timer)
var stats: Stats
var summary_lines: Array = []   # end-of-match summary (server computes; clients receive)
var leaderboard_path := Leaderboard.DEFAULT_PATH
var ranked_path := Ranked.DEFAULT_PATH
var ranked_match := false       # competitive queue or --ranked: ratings change at FINAL
var pending_teams := {}         # name -> team (matchmaker's rating-balanced split)
var ranked_line := ""
var player_name := "You"
var profile := Cosmetics.new()
var profile_path := Cosmetics.DEFAULT_PATH
var looks := {}            # athlete_id -> look (view-only)
var peer_looks := {}       # server: peer_id -> sanitized look
var xp_line := ""
var achievement_line := ""
var replay := Replay.new()
var replay_active := false      # views show replay frames instead of the live sim
var replay_viewer := false      # --replay=FILE standalone viewer
var replay_dir := "user://replays"
var saved_replay := ""
var my_ranks := ""
var potg: Array = []            # players of the game (server picks; clients receive)
var team_totals: Array = []     # per-team box score for the lobby's game overview
var postgame_t := -1.0          # >= 0: counting down to the players-of-the-game presentation
var postgame: Control           # the presentation while it plays
var postgame_done := false
var field_root: Node3D
var athlete_root: Node3D
var my_id := -1          # the human's athlete (QB on offense, LB on defense)
var dead_t := 0.0
var auto_next := true
var los_marker: MeshInstance3D
var fd_marker: MeshInstance3D
var route_lines: MeshInstance3D
var route_mesh := ImmediateMesh.new()
var input_override = null   # tests/bots: Vector2 replaces keyboard movement
var sprint_override = null  # tests/bots: bool replaces the Shift key
var net: NetSession
var net_tick := 0
var predictor := Predictor.new()
var interp := Interp.new()
var latest_snap_tick := 0
var latest_snap_at := 0.0
var camera: Camera3D
var hud: Label
var auto_call := false
var pres: Presentation   # visuals-only layer (ball model, rings, FX, overlay)

static func to_world(p: Vector2, h: float = 0.0) -> Vector3:
	return Vector3(p.x, h, -p.y)

func _ready() -> void:
	pres = Presentation.new()
	add_child(pres)
	_build_environment()
	_build_ball_view()
	_build_aim_visuals()
	var args := _cli_args()
	if args.has("leaderboard-file"):
		leaderboard_path = str(args["leaderboard-file"])
	if args.has("ranked-file"):
		ranked_path = str(args["ranked-file"])
	if args.has("name"):
		player_name = str(args["name"]).strip_edges().left(16)
	ranked_match = args.has("ranked")
	if args.has("training-file"):
		training_path = str(args["training-file"])
	if args.has("replay-dir"):
		replay_dir = str(args["replay-dir"])
	if args.has("profile-file"):
		profile_path = str(args["profile-file"])
	profile.load_file(profile_path)
	if args.has("equip"):
		for pair in str(args["equip"]).split(","):
			var kv := pair.split(":")
			if kv.size() == 2:
				var v = int(kv[1]) if kv[0] == "number" else kv[1]
				print("EQUIP %s=%s: %s" % [kv[0], kv[1], profile.equip(kv[0], v)])
		profile.save(profile_path)
	if args.has("leaderboard"):
		_print_leaderboards(str(args["leaderboard"]) if args["leaderboard"] is String else "")
		get_tree().quit()
		return
	configure(MatchConfig.normalize(args.get("size", 7)), str(args.get("practice", "")) if args.has("practice") else "",
		str(args.get("mode", "classic")))
	_setup_net()
	if args.has("replay"):
		open_replay(str(args["replay"]))
	route_lines = MeshInstance3D.new()
	route_lines.name = "RouteLines"
	route_lines.mesh = route_mesh
	var rlm := StandardMaterial3D.new()
	rlm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rlm.vertex_color_use_as_albedo = true
	rlm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rlm.cull_mode = BaseMaterial3D.CULL_DISABLED
	rlm.no_depth_test = false
	route_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	route_lines.material_override = rlm
	add_child(route_lines)
	for v in views:
		v.sync()
	camera = Camera3D.new()
	camera.name = "FollowCamera"
	camera.fov = 65
	add_child(camera)
	camera.make_current()
	hud = Label.new()
	hud.name = "HUD"
	hud.position = Vector2(16, 16)
	var layer := CanvasLayer.new()
	layer.add_child(hud)
	add_child(layer)

## (Re)build the whole match for a size: field, roster, sim, views. Used at start,
## and on clients when the host's size differs.
func configure(size: int, practice: String = "", mode: String = "classic") -> void:
	match_mode = "chaosball" if mode == "chaosball" else "classic"
	match_size = 3 if match_mode == "chaosball" else MatchConfig.normalize(size)
	drill = null
	if practice != "":
		drill = Drills.new()
		drill.load_bests(training_path)
		match_size = 7
	for r in [field_root, athlete_root]:
		if r:
			remove_child(r)
			r.queue_free()
	field_root = Node3D.new()
	field_root.name = "FieldRoot"
	add_child(field_root)
	athlete_root = Node3D.new()
	athlete_root.name = "AthleteRoot"
	add_child(athlete_root)
	world = World.new()
	field = world.field
	roster = Roster.new()
	ai = AI.new()
	predictor = Predictor.new()
	interp = Interp.new()
	views = []
	world.set_ruleset(match_mode)
	_spawn_teams()
	_build_field()
	if drill != null:
		TrainingArt.build(field_root, drill, field)
	series = Match.new(world)
	_start_series()
	world.event.connect(_on_world_event)
	stats = Stats.new()
	stats.attach(world, owner_name)
	replay = Replay.new()
	replay.attach(world)
	replay.meta = {"size": match_size, "mode": match_mode}
	replay_active = false
	summary_lines = []
	if postgame != null:
		postgame.get_parent().queue_free()
		postgame = null
	potg = []
	team_totals = []
	postgame_t = -1.0
	postgame_done = false
	series.match_event.connect(_on_match_event)
	if drill != null:
		world.event.connect(drill.on_event)
		if drill.kind != "scrimmage":
			drill.start_rep(world)
	los_marker = _marker(Color(0.2, 0.5, 1.0), "LOSMarker")
	fd_marker = _marker(Color(1.0, 0.85, 0.1), "FirstDownMarker")
	looks = {}
	if not is_client():
		_sync_looks()
	for v in views:
		v.sync()

## Host/offline: rebuild athlete looks (yours + peers'), apply to views, broadcast.
func _sync_looks() -> void:
	looks = {}
	looks[my_id] = profile.equipped.duplicate()
	if is_server():
		for peer in net.peer_athlete:
			if peer_looks.has(peer):
				looks[net.peer_athlete[peer]] = peer_looks[peer]
	_apply_looks()
	if is_server():
		net.broadcast_event("looks", {"looks": looks})

func _apply_looks() -> void:
	for aid in looks:
		var i := int(aid)
		if i >= 0 and i < views.size() and views[i].is_inside_tree():
			views[i].apply_look(looks[aid])

func _spawn_teams() -> void:
	var drill_me := -1
	if drill != null:
		MatchConfig.apply_field(world.field, 7)
		drill_me = drill.build(world, _practice_kind())
	if drill_me < 0:
		roster.build(world, match_size)
	my_id = drill_me if drill_me >= 0 else roster.auto_assign(LOCAL_PLAYER)
	var local_team: int = world.get_athlete(my_id).team
	for a in world.athletes:
		var v := PlayerNode.new()
		v.name = "Athlete%d" % a.id
		v.setup(a, TEAM_COLORS[a.team], world, a.team != local_team)
		athlete_root.add_child(v)
		views.append(v)
	controlled_id = my_id
	player = views[controlled_id]

func _build_ball_view() -> void:
	ball_view = Presentation.make_ball()
	add_child(ball_view)

func _build_aim_visuals() -> void:
	reticle = MeshInstance3D.new()
	reticle.name = "Reticle"
	var q := QuadMesh.new()
	q.size = Vector2(2.2, 2.2)
	q.orientation = PlaneMesh.FACE_Y
	reticle.mesh = q
	var rm := ArtMats.shader("res://src/game/art/ring.gdshader")
	rm.set_shader_parameter("color", Color(1.0, 1.0, 1.0, 0.9))
	rm.set_shader_parameter("dashes", 4.0)
	rm.set_shader_parameter("pulse", 1.0)
	reticle.material_override = rm
	reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(reticle)
	for i in ARC_DOTS:
		var d := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var r := lerpf(0.05, 0.11, float(i) / ARC_DOTS)
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = 8
		sm.rings = 4
		d.mesh = sm
		d.material_override = ArtMats.emissive(Color(1.0, 0.9, 0.3).lerp(Color(1.0, 0.55, 0.15), float(i) / ARC_DOTS), 3.0)
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		d.visible = false
		add_child(d)
		arc_dots.append(d)

## Mouse ray onto the turf plane -> field coordinates.
func _update_aim() -> void:
	if camera == null or not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var mp := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mp)
	var dir := camera.project_ray_normal(mp)
	if absf(dir.y) < 0.0001:
		return
	var t := -origin.y / dir.y
	if t > 0.0:
		var hit := origin + dir * t
		aim_point = Vector2(hit.x, -hit.z)

func _update_arc() -> void:
	var qb = world.get_athlete(controlled_id)
	var show := charging and world.ball.is_held_by(controlled_id)
	reticle.position = Vector3(aim_point.x, 0.05, -aim_point.y)
	if not show:
		for d in arc_dots:
			d.visible = false
		return
	var from := Vector3(qb.position.x, qb.position.y, T.RELEASE_HEIGHT)
	var v := Passing.solve_velocity(from, aim_point, charge, world.gravity(), lob_held())
	v += Vector3(qb.velocity.x, qb.velocity.y, 0) * T.THROW_INHERIT
	if kicking():
		from = Vector3(qb.position.x, qb.position.y, T.KICK_HEIGHT)
		v = World.kick_velocity(world.kick_play, qb.position, aim_point, charge)
	var tf := Passing.time_to_height(v, from.z, 0.0, world.gravity())
	for i in ARC_DOTS:
		var t := tf * float(i + 1) / ARC_DOTS
		var p := from + v * t + Vector3(0, 0, -0.5 * world.gravity() * t * t)
		arc_dots[i].position = Vector3(p.x, p.z, -p.y)
		arc_dots[i].visible = true

func _set_charging(on: bool) -> void:
	if on and world.ball.is_held_by(controlled_id) and not charging:
		charging = true
		charge = 0.0
	elif not on and charging:
		charging = false
		if kicking():
			do_action({"a": "kick", "t": aim_point, "p": charge})
		else:
			do_action({"a": "throw", "t": aim_point, "p": charge, "lob": lob_held()})

## The charge meter kicks instead of throwing (punt/FG/PAT called, or a kickoff).
func kicking() -> bool:
	return world.kick_play != "" and not world.kicked

## Coin-toss seed: `--toss=N` for a fixed result, else random.
var toss_seed := -1
var opening_kickoff := true   # false = start on a scrimmage snap (scripted tests)

func _start_series() -> void:
	if drill != null or match_mode == "chaosball" or not opening_kickoff or _cli_args().has("no-kickoff"):
		series.start(0, Drills.LOS if drill != null else -1.0)
		return
	var s := toss_seed if toss_seed >= 0 else int(_cli_args().get("toss", randi() % 2))
	var winner_humans := false
	for id in [my_id] + roster.humans():
		var a = world.get_athlete(id)
		if a and a.team == posmod(s, 2):
			winner_humans = true
	series.start_match(s, winner_humans)

## Display name of whoever controls athlete `aid` right now ("Bot" for AI).
func owner_name(aid: int) -> String:
	var slot := roster.slot_of_athlete(aid)
	var owner: int = roster.slots[slot]["owner"] if slot >= 0 else (LOCAL_PLAYER if aid == my_id else -1)
	if owner < 0:
		return "Bot"
	if lobby.players.has(owner):
		return str(lobby.players[owner]["name"])
	return player_name if owner == LOCAL_PLAYER else "P%d" % owner

func _print_leaderboards(pos: String) -> void:
	var lb := Leaderboard.new()
	lb.load_file(leaderboard_path)
	for p in ([pos] if pos != "" else lb.positions()):
		print(lb.table_text(p, Leaderboard.MAX_ROWS))

## Host/offline: fold this match into the persistent leaderboard; return your ranks.
func _record_leaderboard() -> String:
	var lb := Leaderboard.new()
	lb.load_file(leaderboard_path)
	lb.record_match(stats.to_dict())
	lb.save(leaderboard_path)
	var me := owner_name(my_id)
	var ranks := []
	for k in stats.lines:
		if k.get_slice("|", 0) == me:
			var pos: String = k.get_slice("|", 1)
			ranks.append("%s #%d" % [pos, lb.rank_of(me, pos)])
	return ", ".join(ranks)

## Host: Elo update for every human by final team; returns {name: delta}.
func _record_ranked() -> Dictionary:
	var teams := [[], []]
	for s in roster.slots:
		if s["owner"] >= 0:
			var nm := owner_name(s["athlete_id"])
			if not teams[s["team"]].has(nm):
				teams[s["team"]].append(nm)
	var w := series.winner()
	var rk := Ranked.new()
	rk.load_file(ranked_path)
	rk.ensure_season(Ranked.season_id(Time.get_unix_time_from_system()))
	var deltas := rk.record_match(teams[0], teams[1], 0.5 if w < 0 else (1.0 if w == 0 else 0.0))
	rk.save(ranked_path)
	var labels := {}
	for nm in deltas:
		labels[nm] = rk.label(nm)
	return {"deltas": deltas, "labels": labels}

func _ranked_text(r: Dictionary) -> String:
	var me := owner_name(my_id)
	if not r.get("deltas", {}).has(me):
		return ""
	return "RATING %s (%+d)" % [r["labels"][me], int(round(r["deltas"][me]))]

## XP per human (by name) from this match's stats + result.
func _match_awards() -> Dictionary:
	var lines := {}
	var team_of := {}
	for s in roster.slots:
		if s["owner"] >= 0:
			team_of[owner_name(s["athlete_id"])] = s["team"]
	if roster.slots.is_empty():
		team_of[owner_name(my_id)] = world.get_athlete(my_id).team
	for k in stats.lines:
		var nm: String = k.get_slice("|", 0)
		if nm == "Bot":
			continue
		if not lines.has(nm):
			lines[nm] = {}
		for f in stats.lines[k]:
			lines[nm][f] = lines[nm].get(f, 0.0) + float(stats.lines[k][f])
	var xp := {}
	for nm in team_of:
		xp[nm] = Cosmetics.award_xp(lines.get(nm, {}), series.winner() == team_of[nm])
	return xp

## Per-human achievement context (merged stats, result, deficit overcome, rating).
func _match_contexts(ratings: Dictionary) -> Dictionary:
	var out := {}
	var team_of := {}
	for s in roster.slots:
		if s["owner"] >= 0:
			team_of[owner_name(s["athlete_id"])] = s["team"]
	if roster.slots.is_empty():
		team_of[owner_name(my_id)] = world.get_athlete(my_id).team
	for nm in team_of:
		var line := {}
		for k in stats.lines:
			if k.get_slice("|", 0) == nm:
				for f in stats.lines[k]:
					line[f] = maxf(line.get(f, 0.0), float(stats.lines[k][f])) if f == "max_td_pts" else line.get(f, 0.0) + float(stats.lines[k][f])
		var t: int = team_of[nm]
		out[nm] = {"line": line, "won": series.winner() == t, "deficit": series.max_deficit[t],
			"rating": ratings.get(nm, 0.0), "mode": match_mode}
	return out

## Every machine credits only its own player's local profile (XP + achievements).
func _apply_award(xp: Dictionary, ctx: Dictionary = {}) -> void:
	var me := owner_name(my_id) if not is_client() else player_name
	if not xp.has(me):
		return
	var total := int(xp[me])
	profile.games += 1
	var unlocked := []
	if ctx.has(me):
		var c: Dictionary = ctx[me].duplicate()
		c["games"] = profile.games
		for a in Achievements.evaluate(c, profile.achievements):
			profile.achievements.append(a["id"])
			unlocked.append(a["name"])
			total += int(a["xp"])
	var gained := profile.add_xp(total)
	profile.save(profile_path)
	xp_line = "XP +%d (Level %d%s)" % [total, profile.level(), " - LEVEL UP!" if gained > 0 else ""]
	achievement_line = ("ACHIEVEMENTS: " + ", ".join(unlocked)) if not unlocked.is_empty() else ""

func _on_match_event(n: String, data: Dictionary) -> void:
	if n in ["timeout", "clock_warning"]:
		_on_world_event(n, data)
	if n == "final" and drill == null:
		saved_replay = _save_replay()
		print("REPLAY saved: %s" % saved_replay)
	if n == "final":
		if not is_client() and drill == null:
			my_ranks = _record_leaderboard()
			var ratings := {}
			if ranked_match:
				var r := _record_ranked()
				var rk := Ranked.new()
				rk.load_file(ranked_path)
				profile.season_rewards = rk.rewards.get(owner_name(my_id), [])
				for nm in r.get("deltas", {}):
					ratings[nm] = rk.rating(nm)
				ranked_line = _ranked_text(r)
				print("RANKED: %s" % str(r))
				if is_server():
					net.broadcast_event("ranked", r)
			var awards := _match_awards()
			var ctx := _match_contexts(ratings)
			_apply_award(awards, ctx)
			if is_server():
				net.broadcast_event("awards", {"xp": awards, "ctx": ctx})
		summary_lines = stats.summary_lines()
		print("MATCH SUMMARY:\n  " + "\n  ".join(summary_lines))
		if drill == null and not is_client():
			potg = _decorate_potg(Potg.pick(stats.athletes, series.winner()))
			team_totals = Potg.team_totals(stats.athletes)
			print("PLAYERS OF THE GAME: %s" % ", ".join(potg.map(func(e): return "%s (%s %s)" % [e["name"], e["pos"], e["score"]])))
			_queue_postgame()
		if is_server():
			net.broadcast_event("summary", {"lines": summary_lines, "potg": potg, "teams": team_totals})

## Display name, jersey number and cosmetics for each pick (sent to clients as-is).
func _decorate_potg(picks: Array) -> Array:
	for e in picks:
		var aid: int = e["id"]
		var lk: Dictionary = looks.get(aid, {})
		e["name"] = "CPU" if e["owner"] == "Bot" else e["owner"]
		e["number"] = int(lk.get("number", (aid % 90) + 10))
		e["look"] = lk.duplicate()
	return picks

# --- post-game: FINAL hold -> players of the game -> lobby ------------------

func _queue_postgame() -> void:
	if replay_viewer or postgame_done or postgame_t >= 0.0:
		return
	postgame_t = 0.0

func _tick_postgame(delta: float) -> void:
	if postgame_t < 0.0 or postgame != null:
		return
	postgame_t += delta
	if postgame_t >= POSTGAME_HOLD:
		start_postgame()

## Show the players-of-the-game presentation (skipped when nobody recorded a stat).
func start_postgame() -> void:
	if postgame != null or postgame_done:
		return
	if replay_active and not replay_viewer:
		stop_replay()
	if potg.is_empty():
		finish_postgame()
		return
	var layer := CanvasLayer.new()
	layer.name = "Postgame"
	layer.layer = 60     # over the match HUD, under the Esc menu (90)
	postgame = PotgStage.new()
	postgame.setup(potg, {"score": series.score.duplicate(), "winner": series.winner(),
		"team_colors": TEAM_COLORS, "team_names": Potg.TEAM_NAMES,
		"local_team": world.get_athlete(my_id).team})
	postgame.finished.connect(finish_postgame)
	layer.add_child(postgame)
	add_child(layer)

## Everything the lobby's game overview shows, as plain data.
func match_overview() -> Dictionary:
	var me := player_name if is_client() else owner_name(my_id)
	var mine := summary_lines.filter(func(l): return str(l).begins_with(me + " "))
	var my_team: int = world.get_athlete(my_id).team if world.get_athlete(my_id) else 0
	return {"score": series.score.duplicate(), "winner": series.winner(), "my_team": my_team,
		"team_names": Potg.TEAM_NAMES, "mode": match_mode, "size": match_size, "ranked": ranked_match,
		"online": net != null, "me": me, "potg": potg, "teams": team_totals,
		"my_lines": mine.map(func(l): return str(l).trim_prefix(me + " ")),
		"xp": xp_line, "achievements": achievement_line, "rating": ranked_line, "ranks": my_ranks,
		"replay": saved_replay, "when": Time.get_datetime_string_from_system(false, true)}

## Presentation over: back to the lobby (menu launches) with the game overview.
func finish_postgame() -> void:
	if postgame_done:
		return
	postgame_done = true
	var ov := match_overview()
	print("POSTGAME done -> lobby overview: %s" % str(ov["score"]))
	if postgame != null:
		postgame.get_parent().queue_free()
		postgame = null
	var launch := get_node_or_null("/root/Launch")
	if launch and launch.from_menu:
		launch.go_to_menu("", ov)

## Ctrl held on release = lob (high arc; catch your own pass in Chaosball).
var lob_override = null
func lob_held() -> bool:
	return lob_override if lob_override != null else Input.is_key_pressed(KEY_CTRL)

## All human actions go through here: local authority offline/host, sent to server as client.
func do_action(action: Dictionary) -> bool:
	if is_client():
		net.send_action(action)
		return true
	if action.get("a", "") in ["cycle", "team", "pick"]:
		var aid := roster_action(LOCAL_PLAYER, action)
		if aid >= 0:
			my_id = aid
			set_controlled(aid)
			_sync_looks()
		return aid >= 0
	return Protocol.apply_action(series, controlled_id, action)

func is_client() -> bool:
	return net != null and net.mode == NetSession.Mode.CLIENT

func is_server() -> bool:
	return net != null and net.mode == NetSession.Mode.SERVER

func _cli_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		out[kv[0]] = kv[1] if kv.size() > 1 else true
	var launch := get_node_or_null("/root/Launch")   # main menu choices (src/ui/launch.gd)
	if launch:
		out.merge(launch.options, true)
	return out

func _setup_net() -> void:
	var args := _cli_args()
	if args.has("matchmaker"):
		var mms := MMServer.new()
		mms.name = "Matchmaker"
		add_child(mms)
		var p := int(args.get("port", MMServer.DEFAULT_PORT))
		print("MM server on %d: %s" % [p, error_string(mms.start(p))])
		return
	if args.has("queue"):
		_queue_up(args)
		return
	if not (args.has("host") or args.has("join")):
		return
	var port := int(args.get("port", NetSession.DEFAULT_PORT))
	if args.has("host"):
		_host_game(port, {"playclock": float(args.get("playclock", -1.0)), "no_lobby": args.has("no-lobby"),
			"start_when_ready": args.has("start-when-ready"), "advertise": str(args.get("advertise", _local_ipv4()))})
	else:
		_join_game(str(args["join"]), port, {})

func _ensure_net() -> void:
	if net == null:
		net = NetSession.new()
		net.name = "Net"
		add_child(net)

## Open a hosted match (lobby by default). opts: playclock, no_lobby, start_when_ready, advertise, expected, size, mode
func _host_game(port: int, opts: Dictionary) -> String:
	_ensure_net()
	if opts.get("playclock", -1.0) > 0.0:
		debug_playclock = opts["playclock"]
		series.clock.play_clock = debug_playclock
	net.match_size = match_size
	var err := net.host(port, func(peer): return roster.auto_assign(peer), func(peer): roster.release(peer))
	print("NET host on %d: %s" % [port, error_string(err)])
	if opts.get("no_lobby", false):
		return ""
	lobby = Lobby.new()
	lobby.host_id = LOCAL_PLAYER
	lobby.add(LOCAL_PLAYER, player_name if player_name != "You" else "Host")
	lobby.settings["size"] = MatchConfig.normalize(opts.get("size", match_size))
	if opts.get("game", "classic") == "chaosball":
		lobby.settings["mode"] = "chaosball"
		lobby.settings["size"] = 3
	lobby.expected = int(opts.get("expected", 0))
	lobby.code = InviteCode.encode(str(opts.get("advertise", _local_ipv4())), port)
	if opts.get("start_when_ready", false):
		lobby.set_ready(LOCAL_PLAYER, true)
	net.lobby = lobby
	net.lobby_mode = true
	net.lobby_changed.connect(func(): net.broadcast_lobby(lobby.to_dict()))
	print("NET invite code: %s" % lobby.code)
	return lobby.code

## Join a match by invite code or address. opts: auto_ready
func _join_game(target: String, port: int, opts: Dictionary) -> void:
	_ensure_net()
	if InviteCode.looks_like_code(target):
		var d := InviteCode.decode(target)
		target = d["ip"]
		port = d["port"]
	var err := net.join(target, port)
	print("NET join %s:%d: %s" % [target, port, error_string(err)])
	auto_next = false
	net.welcomed.connect(_on_assigned)
	var auto_ready: bool = opts.get("auto_ready", false)
	var readied := [false]
	net.lobby_received.connect(func(st):
		lobby.from_dict(st)
		if not readied[0] and lobby.phase == Lobby.Phase.LOBBY:
			readied[0] = true
			if player_name != "You":
				net.send_lobby_action({"a": "name", "n": player_name})
			if auto_ready:
				net.send_lobby_action({"a": "ready"}))
	net.snapshot_received.connect(_on_snapshot)
	net.event_received.connect(_on_world_event)

## Queued for matchmaking and not yet hosting/joining a match.
func searching() -> bool:
	return mm_client != null and net == null

## Matchmaking: queue, then host or join as the matchmaker decides.
var mm_client: MMClient
func _queue_up(args: Dictionary) -> void:
	mm_client = MMClient.new()
	mm_client.name = "Queue"
	add_child(mm_client)
	var addr := str(args.get("mm", "127.0.0.1"))
	var mm_port := MMServer.DEFAULT_PORT
	if addr.find(":") > 0:
		mm_port = int(addr.get_slice(":", 1))
		addr = addr.get_slice(":", 0)
	var mode := str(args["queue"])
	var advertise := str(args.get("advertise", _local_ipv4()))
	mm_client.host_match.connect(func(m):
		_end_warmup(args)
		ranked_match = m.get("mode", "") == "competitive"
		pending_teams = m.get("teams", {}) if m.get("teams") is Dictionary else {}
		var port := int(args.get("host-port", 25000 + randi() % 5000))
		var code := _host_game(port, {"start_when_ready": true, "expected": int(m.get("expected", 2)),
			"size": int(m.get("size", 7)), "advertise": advertise, "game": str(m.get("game", "classic"))})
		lobby.settings["half_minutes"] = 5
		print("QUEUE matched (%s): hosting %s" % [m.get("mode", "?"), code])
		mm_client.send_hosting(code))
	mm_client.join_match.connect(func(code):
		_end_warmup(args)
		print("QUEUE matched: joining %s" % code)
		_join_game(code, 0, {"auto_ready": true}))
	var rk := Ranked.new()
	rk.load_file(ranked_path)
	var err := mm_client.queue_up(addr, mm_port, mode, MatchConfig.normalize(args.get("size", 7)),
		float(args.get("rating", rk.rating(player_name))), player_name,
		str(args.get("party", "")).get_slice(":", 0), int(str(args.get("party", "x:1")).get_slice(":", 1)) if str(args.get("party", "")).find(":") > 0 else 1,
		"chaosball" if str(args.get("mode", "")) == "chaosball" else "classic")
	print("QUEUE %s via %s:%d: %s" % [mode, addr, mm_port, error_string(err)])
	queue_started_ms = Time.get_ticks_msec()
	# Waiting lobby: warm up on the training ground until the match is found.
	if not args.has("no-warmup"):
		start_practice("hub")
		print("QUEUE warm-up: training ground")

## Match found: leave the training ground and rebuild the queued match's world.
func _end_warmup(args: Dictionary) -> void:
	if drill == null:
		return
	charging = false
	configure(MatchConfig.normalize(args.get("size", 7)), "", str(args.get("mode", "classic")))
	print("QUEUE warm-up over: match found")

## "SEARCHING FOR A CASUAL MATCH  0:42" while queued.
func queue_text() -> String:
	var secs := int((Time.get_ticks_msec() - queue_started_ms) / 1000)
	return "SEARCHING FOR A %s MATCH  %d:%02d" % [str(_cli_args().get("queue", "")).to_upper(), secs / 60, secs % 60]

func _practice_kind() -> String:
	if _pending_practice != "":
		return _pending_practice
	var k := str(_cli_args().get("practice", ""))
	return k if Drills.valid(k) else "passing"

var _pending_practice := ""

## Start an offline practice session (also used by tests).
func start_practice(kind: String) -> void:
	_pending_practice = kind
	configure(7, kind)
	_pending_practice = ""

func _local_ipv4() -> String:
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			return a
	return "127.0.0.1"

## True while the private lobby is open (server) / we haven't been placed yet (client).
func in_lobby() -> bool:
	if searching():
		return drill == null   # queued + warming up on the training ground = playable
	if is_server():
		return net.lobby_mode and lobby.phase == Lobby.Phase.LOBBY
	if is_client():
		return net.my_athlete < 0
	return false

## Lobby input: Enter = ready; host: 3/5/7 size, H half length.
func lobby_key(keycode: int) -> void:
	if is_client():
		if keycode == KEY_ENTER:
			net.send_lobby_action({"a": "ready"})
		return
	var changed := false
	match keycode:
		KEY_ENTER: changed = lobby.toggle_ready(LOCAL_PLAYER)
		KEY_3: changed = lobby.set_setting(LOCAL_PLAYER, "size", 3)
		KEY_5: changed = lobby.set_setting(LOCAL_PLAYER, "size", 5)
		KEY_7: changed = lobby.set_setting(LOCAL_PLAYER, "size", 7)
		KEY_M:
			changed = lobby.set_setting(LOCAL_PLAYER, "mode", "chaosball" if lobby.settings.get("mode", "classic") == "classic" else "classic")
		KEY_H:
			var i := (Lobby.HALF_MINUTES.find(lobby.settings["half_minutes"]) + 1) % Lobby.HALF_MINUTES.size()
			changed = lobby.set_setting(LOCAL_PLAYER, "half_minutes", Lobby.HALF_MINUTES[i])
	if changed:
		net.broadcast_lobby(lobby.to_dict())

## Server: lobby tick — apply client lobby actions, start when everyone is ready.
func _step_lobby() -> void:
	var changed := false
	for la in net.take_lobby_actions():
		match la[1].get("a", ""):
			"ready": changed = lobby.toggle_ready(la[0]) or changed
			"name": changed = lobby.set_name(la[0], str(la[1].get("n", ""))) or changed
	if changed:
		net.broadcast_lobby(lobby.to_dict())
	if lobby.all_ready():
		_start_from_lobby()

func _start_from_lobby() -> void:
	if not lobby.start():
		return
	configure(lobby.settings["size"], "", lobby.settings.get("mode", "classic"))
	series.clock.half_length = lobby.settings["half_minutes"] * 60.0
	series.clock.reset()
	if debug_playclock > 0.0:
		series.clock.play_clock = debug_playclock
	net.match_size = match_size
	net.match_mode = match_mode
	# Competitive: seat everyone on the matchmaker's rating-balanced team (by name).
	var host_name: String = lobby.players[LOCAL_PLAYER]["name"]
	if pending_teams.has(host_name) and world.get_athlete(my_id).team != int(pending_teams[host_name]):
		my_id = roster.swap_team(LOCAL_PLAYER)
		set_controlled(my_id)
	for id in lobby.players:
		if id == LOCAL_PLAYER:
			continue
		var nm: String = lobby.players[id]["name"]
		var aid := roster.auto_assign_team(id, int(pending_teams[nm])) if pending_teams.has(nm) else roster.auto_assign(id)
		if aid >= 0:
			net.set_assignment(id, aid)
	net.broadcast_lobby(lobby.to_dict())
	_sync_looks()
	var seats := []
	for s in roster.slots:
		if s["owner"] >= 0:
			seats.append("%s->%d" % [owner_name(s["athlete_id"]), s["team"]])
	print("NET match started: %s" % lobby.summary())
	print("NET seats: %s (ranked=%s, teams=%s)" % [", ".join(seats), ranked_match, str(pending_teams)])

## Client: server (re)assigned our athlete (join, position change, team swap).
func _on_assigned(aid: int) -> void:
	if net.host_size != match_size or net.host_mode != match_mode:
		configure(net.host_size, "", net.host_mode)
	my_id = aid
	predictor = Predictor.new()
	set_controlled(aid)
	print("NET assigned athlete %d" % aid)
	# Our look goes to the host; we only show it once the host echoes it back.
	net.send_action({"a": "look", "look": profile.equipped})

## Roster changes (position/team). Authoritative on server/offline; only outside live play.
## Returns the player's (possibly new) athlete id, or -1 if rejected.
func roster_action(player: int, action: Dictionary) -> int:
	if world.phase == World.Phase.LIVE:
		return -1
	match action.get("a", ""):
		"cycle":
			return roster.cycle_position(player)
		"team":
			return roster.swap_team(player)
		"pick":
			var slot = action.get("slot", -1)
			if slot is int and roster.claim(player, slot):
				return roster.athlete_of(player)
	return -1

## Client: authoritative state in, then re-predict own athlete on top of it.
func _on_snapshot(snap: Dictionary) -> void:
	Protocol.apply_snapshot(series, snap)
	interp.push(int(snap["t"]), Interp.xy_from_snapshot(snap), Interp.ball_from_snapshot(snap))
	latest_snap_tick = int(snap["t"])
	latest_snap_at = Time.get_ticks_msec() / 1000.0
	var me = world.get_athlete(my_id)
	if me:
		predictor.reconcile(me, int(snap.get("ack", {}).get(my_id, 0)), world)

## Client: draw others ~100 ms in the past, interpolated between snapshots.
func _apply_interpolation() -> void:
	if interp.buf.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var t := latest_snap_tick / Interp.TICK_RATE + (now - latest_snap_at) - INTERP_DELAY
	var smp := interp.sample(t)
	var xy: PackedFloat32Array = smp["xy"]
	for i in mini(world.athletes.size(), xy.size() / 2):
		if i != my_id:
			world.athletes[i].position = Vector2(xy[i * 2], xy[i * 2 + 1])
	if not world.ball.is_held_by(my_id):
		world.ball.position = smp["ball"]

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_set_charging(e.pressed)
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
		do_action({"a": "tackle"})


func _on_world_event(n: String, d: Dictionary) -> void:
	if pres:
		pres.on_event(n, d)
	if n == "incomplete" and last_whistle == "":
		last_whistle = "INCOMPLETE"
	if n in ["tackle", "out_of_bounds", "breakup", "touchdown", "explode", "touchback", "kick_out_of_bounds", "kick_downed"]:
		last_whistle = n.replace("kick_", "").replace("_", " ").to_upper()
	if n == "field_goal":
		last_whistle = "FIELD GOAL GOOD" if d.get("good", false) else "FIELD GOAL NO GOOD"
		banner = "IT'S GOOD!" if d.get("good", false) else "NO GOOD!"
		banner_t = 2.0
	if n == "kick_blocked":
		banner = "BLOCKED!"
		banner_t = 2.0
	if n == "ranked":
		ranked_line = _ranked_text(d)
	if n == "looks" and d.get("looks") is Dictionary:
		looks = d["looks"]
		_apply_looks()
	if n == "awards" and d.get("xp") is Dictionary:
		_apply_award(d["xp"], d.get("ctx", {}) if d.get("ctx") is Dictionary else {})
	if n == "touchdown":
		var cid: int = d.get("carrier", -1)
		if cid >= 0 and cid < views.size():
			views[cid].celebrate(str(looks.get(cid, {}).get("celebration", "none")))
	if n == "summary":
		summary_lines = d.get("lines", []) if d.get("lines") is Array else []
		potg = d.get("potg", []) if d.get("potg") is Array else []
		team_totals = d.get("teams", []) if d.get("teams") is Array else []
		if is_client():
			_queue_postgame()
	if n == "snap":
		last_whistle = ""
	if n in ["interception", "fumble", "recovery"]:
		banner = {"interception": "INTERCEPTION!", "fumble": "FUMBLE!", "recovery": "RECOVERED!"}[n]
		banner_t = 2.0
	if is_server():
		net.broadcast_event(n, d)
	# Offline convenience: follow the ball to the receiver. Online: fixed athlete (Gridiron parity).
	if net == null and n == "catch" and world.get_athlete(d["by"]).team == world.offense_team:
		set_controlled(d["by"])
	if n == "handoff" and d["by"] == controlled_id:
		charging = false
		if net == null:
			set_controlled(d["to"])
	# Offline: take control of whoever on your team just took the ball away.
	if net == null and n in ["interception", "recovery", "kick_catch"] and world.get_athlete(d["by"]).team == world.get_athlete(my_id).team:
		set_controlled(d["by"])

func _marker(c: Color, n: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(field.width, 0.55)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := ArtMats.shader("res://src/game/art/line_marker.gdshader")
	m.set_shader_parameter("color", c)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = n
	field_root.add_child(mi)
	return mi

## Defense pre-snap HUD: stance state for the local athlete.
func presnap_defense_prompt(a) -> String:
	if a == null:
		return "PRE-SNAP"
	if a.role == Athlete.Role.DL:
		return "PRE-SNAP (hold your stance)"
	return "PRE-SNAP (Space: break stance)" if a.set_lock else "PRE-SNAP: ROAMING"

func next_play() -> void:
	series.next_play()
	dead_t = 0.0
	last_whistle = ""
	set_controlled(my_id)

func set_controlled(id: int) -> void:
	controlled_id = id
	player = views[id]
	var local_team: int = world.get_athlete(my_id).team
	for view in views:
		var opponent: bool = view.athlete.team != local_team
		if view.is_opponent != opponent:
			view.set_opponent(opponent)

func read_input() -> Vector2:
	if input_override != null:
		return input_override
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): v.y += 1
	if Input.is_key_pressed(KEY_S): v.y -= 1
	if Input.is_key_pressed(KEY_D): v.x += 1
	if Input.is_key_pressed(KEY_A): v.x -= 1
	return v

func _input(e: InputEvent) -> void:
	if e is InputEventKey and not e.pressed and e.keycode == KEY_J:
		_set_charging(false)

func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	if in_lobby():
		if not searching():
			lobby_key(e.keycode)
		return
	if e.keycode == KEY_V:
		toggle_replay()
		return
	if replay_viewer:
		match e.keycode:
			KEY_SPACE: replay.paused = not replay.paused
			KEY_RIGHT: replay.seek_play(replay.current_play() + 1)
			KEY_LEFT: replay.seek_play(replay.current_play() - 1)
			KEY_BRACKETRIGHT: replay.speed = minf(2.0, replay.speed * 2.0)
			KEY_BRACKETLEFT: replay.speed = maxf(0.25, replay.speed / 2.0)
		return
	if replay_active:
		return
	match e.keycode:
		KEY_SPACE:
			do_action({"a": "snap"})
		KEY_1:
			do_action({"a": "toss", "c": "receive"} if series.state == Match.State.TOSS else {"a": "try", "n": 1})
		KEY_2:
			do_action({"a": "toss", "c": "kick"} if series.state == Match.State.TOSS else {"a": "try", "n": 2})
		KEY_K:
			var ki := (World.KICK_CALLS.find(world.kick_play) + 1) % World.KICK_CALLS.size()
			do_action({"a": "kick_call", "k": World.KICK_CALLS[ki]})
		KEY_E:
			do_action({"a": "tackle"})
		KEY_G:
			do_action({"a": "handoff"})
		KEY_U:
			if drill == null:
				do_action({"a": "timeout"})
		KEY_J:
			_set_charging(true)
		KEY_Y:
			if world.phase == World.Phase.PRESNAP:
				auto_call = not auto_call
		KEY_L:
			do_action({"a": "recall_call"})
		KEY_X:
			do_action({"a": "flip_play"})
		KEY_Q:
			var me = world.get_athlete(my_id)
			if me != null and me.team != world.offense_team and not world.defensive_call.is_empty():
				var calls := World.DefensivePlaybook.CALLS.keys()
				var next := (calls.find(world.defensive_call) + 1) % calls.size()
				do_action({"a": "defense", "p": calls[next]})
			else:
				var plays := world.available_plays()
				var i := (plays.find(world.play_name) + 1) % plays.size()
				do_action({"a": "play", "p": plays[i]})
		KEY_F:
			if world.route_of.has(my_id):
				var j := (Routes.ROUTE_NAMES.find(world.route_of[my_id]) + 1) % Routes.ROUTE_NAMES.size()
				do_action({"a": "route", "r": Routes.ROUTE_NAMES[j]})
		KEY_TAB:
			do_action({"a": "cycle"})
		KEY_T:
			do_action({"a": "team"})
		KEY_R:
			if world.phase == World.Phase.DEAD and not is_client():
				next_play()
		KEY_BACKSPACE:
			if drill != null and net == null:
				start_practice("hub")   # back to the training ground

func _physics_process(delta: float) -> void:
	if charging:
		charge = minf(1.0, charge + delta / T.THROW_CHARGE_TIME)
	var my_input := {"dir": read_input(), "sprint": sprint_override if sprint_override != null else Input.is_key_pressed(KEY_SHIFT)}
	if in_lobby():
		if is_server():
			_step_lobby()
		_render()
		return
	if replay_active:
		replay.advance(delta)
		if replay.ended() and not replay_viewer:
			stop_replay()
		elif net != null and not is_client():
			_step_authoritative(delta, my_input)   # host keeps the match running
		_render_replay()
		return
	if is_client():
		# Predict own athlete now; server stays authoritative and reconciles via acks.
		var seq := predictor.record(my_input["dir"], my_input["sprint"], delta)
		net.send_input(my_input["dir"], my_input["sprint"], seq)
		var me = world.get_athlete(my_id)
		if me and net.my_athlete >= 0:
			world.predict_step(me, my_input["dir"], my_input["sprint"], delta)
			if world.ball.is_held_by(my_id):
				world.ball.position = Vector3(me.position.x, me.position.y, T.BALL_CARRY_HEIGHT)
		_apply_interpolation()
	else:
		_step_authoritative(delta, my_input)
	replay.capture(world)
	_render()

func _step_authoritative(delta: float, my_input: Dictionary) -> void:
	if drill == null:
		series.tick(delta)          # practice never runs the clocks
	if drill != null and drill.kind != "scrimmage":
		if drill.tick(world, delta):
			drill.start_rep(world)
			last_whistle = ""
			set_controlled(my_id)
		if drill.portal != "":
			start_practice(drill.portal)   # walked into a training-ground portal
			return
	elif world.phase == World.Phase.DEAD and auto_next and not series.is_final():
		dead_t += delta
		if dead_t >= NEXT_PLAY_DELAY:
			next_play()
	var humans: Array = [controlled_id] + roster.humans()
	if is_server():
		for pa in net.take_actions():
			var act = pa[2]
			if act is Dictionary and act.get("a", "") in ["cycle", "team", "pick"]:
				var aid := roster_action(pa[0], act)
				if aid >= 0:
					net.set_assignment(pa[0], aid)
					_sync_looks()
			elif act is Dictionary and act.get("a", "") == "look":
				peer_looks[pa[0]] = Cosmetics.sanitize_look(act.get("look", {}))
				_sync_looks()
			else:
				Protocol.apply_action(series, pa[1], act)
	var snap_delay := T.AI_SNAP_DELAY
	if drill == null and not world.is_chaos() and not auto_call and not humans.is_empty():
		snap_delay = T.HUDDLE_SECONDS
	ai.presnap_tick(world, humans, delta, series.downs.down, series.downs.distance(), snap_delay)
	var inputs := ai.think(world, humans)
	if drill != null:
		drill.override_inputs(world, inputs)
	inputs[controlled_id] = my_input
	if is_server():
		for aid in net.inputs:
			inputs[aid] = net.inputs[aid]
	world.step(inputs, delta)
	if is_server():
		net_tick += 1
		if net_tick % SNAPSHOT_EVERY == 0:
			net.broadcast_snapshot(Protocol.encode_snapshot(series, net_tick, net.acks()))

## Instant replay of the last play at half speed (V). Offline the match pauses.
func toggle_replay() -> bool:
	if replay_active:
		stop_replay()
		return true
	var p := replay.last_play()
	if p.is_empty() or world.phase == World.Phase.LIVE:
		return false
	replay.play_range(p["start"], p["end"], 0.5)
	replay_active = true
	return true

func stop_replay() -> void:
	replay_active = false
	replay_viewer = false

## Standalone viewer for a saved replay file.
func open_replay(path: String) -> bool:
	var r := Replay.new()
	if not r.load_file(path):
		print("REPLAY load failed: %s" % path)
		return false
	configure(int(r.meta.get("size", 7)), "", str(r.meta.get("mode", "classic")))
	replay = r
	replay.time = 0.0
	replay_viewer = true
	replay_active = true
	print("REPLAY opened %s: %d frames, %d plays" % [path, r.frames.size(), r.plays.size()])
	return true

func _save_replay() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(replay_dir))
	var path := "%s/%s.replay" % [replay_dir, Time.get_datetime_string_from_system().replace(":", "-")]
	return path if replay.save(path) else ""

## Views read replay frames (view-only; the sim is untouched).
func _render_replay() -> void:
	var smp := replay.sample()
	if smp.is_empty():
		return
	var pos: Array = smp["pos"]
	for i in mini(pos.size(), views.size()):
		views[i].place(Vector3(pos[i].x, 0, -pos[i].y), views[i].rotation.y)
	var b: Vector3 = smp["ball"]
	_place_ball(Vector3(b.x, b.z, -b.y))

## Per physics tick: copy sim state into view targets. Cheap, change-driven work only.
## Anything that moves on screen is drawn per frame in _render_frame (interpolated).
func _render() -> void:
	for v in views:
		v.sync()
	var b = world.ball.position
	_place_ball(Vector3(b.x, b.z, -b.y))
	los_marker.position = Vector3(field.width / 2.0, 0.03, -series.downs.los)
	fd_marker.position = Vector3(field.width / 2.0, 0.03, -series.downs.first_down_y)
	fd_marker.visible = not series.downs.is_goal_to_go()
	_draw_routes()

## True while the throw-arc preview is visible (tests).
func arc_shown() -> bool:
	return not arc_dots.is_empty() and arc_dots[0].visible

## Ball interpolation target (same teleport rule as athlete views).
func _place_ball(p: Vector3) -> void:
	_ball_prev = p if p.distance_to(_ball_cur) > PlayerNode.TELEPORT_DIST * 2.0 else _ball_cur
	_ball_cur = p
	ball_view.position = p

## Per display frame: draw between the last two sim ticks, so motion is smooth at any
## refresh rate (60 Hz sim on a 144 Hz screen, or a slow frame that ran 2 ticks).
## Runs before presentation.gd's _process (parent first), which then pins a held ball
## to the (interpolated) carrier's hand.
func _render_frame() -> void:
	var f := Engine.get_physics_interpolation_fraction()
	for v in views:
		v.interpolate(f)
	ball_view.position = _ball_prev.lerp(_ball_cur, f)
	_update_aim()
	_update_arc()

## Presnap route art for your own offense only (the defense never sees it):
## flat glowing ribbons, a distinct color per receiver, arrowheads, start dots.
const ROUTE_COLORS := [Color(1.0, 0.82, 0.25), Color(1.0, 0.45, 0.75), Color(0.55, 0.6, 1.0), Color(1.0, 0.55, 0.2), Color(0.75, 0.5, 1.0)]
const MY_ROUTE_COLOR := Color(0.35, 1.0, 0.55)

func _draw_routes() -> void:
	var me = world.get_athlete(my_id)
	var offense: bool = me != null and me.team == world.offense_team
	var is_run := world.is_run_play()
	var show: bool = me != null and world.phase == World.Phase.PRESNAP and (not offense or is_run or not world.route_of.is_empty())
	if not show:
		if _route_key != 0:
			route_mesh.clear_surfaces()
			_route_key = 0
		return
	# Rebuilding an ImmediateMesh re-uploads it to the GPU; only do it when the art's inputs
	# change. Offense art = routes + protection lines, defense art = assignments; both depend
	# on every athlete's position, the calls, the LOS and which side you're on.
	var key_src := [my_id, me.team, world.offense_team, field.width, world.los_y, world.play_name, is_run, world.route_of, world.defensive_call]
	for a in world.athletes:
		key_src.append(a.position)
	var key := hash(key_src)
	if key == _route_key:
		return
	_route_key = key
	route_mesh.clear_surfaces()
	if not offense:
		_draw_defense_routes(me.team)
		return
	route_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var blocks := {}
	if is_run:
		var back := world.find_role(me.team, Athlete.Role.RB)
		var qb := world.find_role(me.team, Athlete.Role.QB)
		if back and qb:
			var mine := back.id == my_id
			var color: Color = MY_ROUTE_COLOR if mine else ROUTE_COLORS[0]
			_route_ribbon([back.position, qb.position] + world.run_path(), color, 0.48 if mine else 0.34)
		blocks = world.run_block_assignments()
	var k := 0
	for id in world.route_of:
		var a = world.get_athlete(id)
		var pts: Array = [a.position] + Routes.path_for(world.route_of[id], a.position, field.width)
		var mine: bool = id == my_id
		var c: Color = MY_ROUTE_COLOR if mine else ROUTE_COLORS[k % ROUTE_COLORS.size()]
		k += 1
		_route_ribbon(pts, c, 0.42 if mine else 0.3)
	for blocker in world.athletes:
		if blocker.team != me.team or blocker.role not in [Athlete.Role.C, Athlete.Role.OL]:
			continue
		var defender = world.get_athlete(blocks.get(blocker.id, -1)) if is_run else world.protection_target(blocker)
		if defender != null:
			var mine: bool = blocker.id == my_id
			_route_ribbon([blocker.position, defender.position], MY_ROUTE_COLOR if mine else Color(0.76, 0.82, 0.90), 0.42 if mine else 0.22)
	route_mesh.surface_end()

func _draw_defense_routes(team: int) -> void:
	if world.defensive_call.is_empty():
		return
	route_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var matchups: Dictionary = world.man_assignments()
	for athlete in world.athletes:
		if athlete.team != team:
			continue
		var assignment: Dictionary = world.defense_assignment(athlete)
		var mine: bool = athlete.id == my_id
		if assignment.kind == "man":
			if matchups.has(athlete.id):
				var receiver = world.get_athlete(matchups[athlete.id])
				_route_ribbon([athlete.position, receiver.position], Color(1.0, 0.82, 0.38), 0.50 if mine else 0.26)
			continue
		var target: Vector2 = assignment.target
		var color := Color(1.0, 0.30, 0.26)
		if assignment.kind == "zone":
			color = Color(0.50, 0.68, 1.0) if assignment.deep else Color(0.24, 0.94, 0.81)
			_disc(target, 2.0 if mine else 1.5, Color(color, 0.35), 0.055, 0.65)
		_route_ribbon([athlete.position, target], color, 0.50 if mine else 0.26)
	route_mesh.surface_end()

func _route_ribbon(pts: Array, c: Color, wdt: float) -> void:
	var h := 0.06
	var total := 0.0
	for i in range(pts.size() - 1):
		total += (pts[i + 1] - pts[i]).length()
	var run := 0.0
	for i in range(pts.size() - 1):
		var p0: Vector2 = pts[i]
		var p1: Vector2 = pts[i + 1]
		var seg := p1 - p0
		if seg.length() < 0.01:
			continue
		var dir := seg.normalized()
		var is_last := i == pts.size() - 2
		if is_last:   # leave room for the arrowhead
			p1 = p1 - dir * minf(1.1, seg.length() * 0.6)
		var n := Vector2(-dir.y, dir.x) * wdt * 0.5
		var a0 := c * Color(1, 1, 1, lerpf(0.75, 1.0, run / maxf(total, 0.01)))
		run += seg.length()
		var a1 := c * Color(1, 1, 1, lerpf(0.75, 1.0, run / maxf(total, 0.01)))
		_tri(p0 + n, p0 - n, p1 + n, a0, a0, a1, h)
		_tri(p1 + n, p0 - n, p1 - n, a1, a0, a1, h)
		if i > 0:   # round the joint
			_disc(p0, wdt * 0.5, a0, h)
		if is_last:
			var tip: Vector2 = pts[i + 1]
			var base := p1
			var wing := Vector2(-dir.y, dir.x) * wdt * 1.6
			_tri(base + wing, base - wing, tip, a1, a1, a1, h)
	_disc(pts[0], wdt * 1.1, c, h)

func _tri(a: Vector2, b: Vector2, c2: Vector2, ca: Color, cb: Color, cc: Color, h: float) -> void:
	for pc in [[a, ca], [b, cb], [c2, cc]]:
		route_mesh.surface_set_color(pc[1])
		route_mesh.surface_add_vertex(Vector3(pc[0].x, h, -pc[0].y))

func _disc(p: Vector2, r: float, c: Color, h: float, depth_scale: float = 1.0) -> void:
	for s in 10:
		var t0 := TAU * s / 10.0
		var t1 := TAU * (s + 1) / 10.0
		_tri(p, p + Vector2(cos(t0), sin(t0) * depth_scale) * r, p + Vector2(cos(t1), sin(t1) * depth_scale) * r, c, c, c, h)

func huddle_remaining() -> int:
	if world.phase != World.Phase.PRESNAP or drill != null or world.is_chaos() or replay_active or auto_call or world.kick_play == "kickoff":
		return 0
	return maxi(0, int(ceil(series.clock.play_clock - (Match.Clock.PLAY_CLOCK - T.HUDDLE_SECONDS))))

func bound_key_name(action: String) -> String:
	var launch := get_node_or_null("/root/Launch")
	var bindings: Dictionary = launch.settings.bindings if launch else {}
	return Controls.key_name(Controls.key_for(action, bindings)).to_upper()

func handoff_hint() -> String:
	if world.handoff_receiver(controlled_id) != null:
		return "%s HANDOFF" % bound_key_name("handoff")
	var holder := world.carrier()
	if world.phase == World.Phase.LIVE and world.is_run_play() and holder and holder.id == controlled_id and holder.role == Athlete.Role.QB and holder.position.y <= world.los_y:
		return "MEET THE BACK"
	return ""

func huddle_calls(team: int) -> String:
	var cards := PackedStringArray()
	if team == world.offense_team:
		for name in world.available_plays():
			cards.append("[%s]" % name if name == world.play_name else name)
	else:
		var ids := World.DefensivePlaybook.CALLS.keys()
		var first := maxi(0, ids.find(world.defensive_call))
		for i in 6:
			var id = ids[(first + i) % ids.size()]
			var name: String = World.DefensivePlaybook.CALLS[id].name
			cards.append("[%s]" % name if id == world.defensive_call else name)
	var rows := PackedStringArray()
	for i in range(0, cards.size(), 3):
		rows.append("   ·   ".join(cards.slice(i, i + 3)))
	return "\n".join(rows)

func _process(delta: float) -> void:
	_render_frame()
	_tick_postgame(delta)
	var target := player.global_position
	# Blocking drill: higher, deeper camera so the QB behind you doesn't hide the rush.
	var desired := target + (Vector3(0, 10, 13) if drill != null and drill.kind == "blocking" else Vector3(0, 6, 9))
	# Exponential smoothing: identical feel at 30, 60 or 144 fps (a delta*k lerp is not).
	camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-6.0 * delta))
	camera.look_at(target + Vector3(0, 1, -4))
	var m = player.athlete
	var my_team: int = world.get_athlete(my_id).team
	var side := "OFFENSE" if world.offense_team == my_team else "DEFENSE (E/RMB to tackle)"
	side = "%s %s [TAB pos, T team]" % [roster.label(roster.slot_of_athlete(my_id)), side]
	if world.offense_team == my_team:
		side += " | PLAY: %s [Q]%s" % [world.play_name, (" | ROUTE: %s [F]" % world.route_of[my_id]) if world.route_of.has(my_id) else ""]
	elif not world.defensive_call.is_empty():
		side += " | CALL: %s [Q]" % World.DefensivePlaybook.CALLS[world.defensive_call].name
	var phase_name: String = ["PRE-SNAP (Space to snap)", "LIVE", "DEAD"][world.phase]
	if world.offense_team != my_team and world.phase == World.Phase.PRESNAP:
		phase_name = presnap_defense_prompt(world.get_athlete(my_id)) + (" | Q: change defensive call" if not world.defensive_call.is_empty() else "")
	if world.phase == World.Phase.DEAD and last_whistle != "":
		phase_name = "%s at %.1f" % [last_whistle, world.dead_ball_spot.y]
	var situation: String = series.downs.label()
	if series.state == Match.State.TRY:
		situation = "TRY for %d (1: kick / 2: from the 10)" % series.try_points
	elif series.state == Match.State.KICKOFF:
		situation = "KICKOFF"
	elif series.state == Match.State.TOSS:
		situation = "COIN TOSS: %s wins (1: receive / 2: kick)" % ("HOME" if series.toss_winner == 0 else "AWAY")
	if world.offense_team == my_team and series.state == Match.State.SCRIMMAGE and not world.is_chaos():
		side += " | KICK: %s [K]" % {"": "none", "punt": "PUNT", "fg": "FIELD GOAL"}.get(world.kick_play, world.kick_play)
	banner_t = maxf(0.0, banner_t - delta)
	if banner_t > 0.0:
		phase_name = banner + "  " + phase_name
	if drill != null and pres and pres.overlay:
		for b in drill.banners:
			pres.overlay.show_drill_banner(b)
		drill.banners.clear()
	if searching() and drill == null:
		hud.text = queue_text() + "..."
		return
	if replay_active:
		var p: int = replay.current_play()
		var lbl: String = replay.plays[p]["label"] if p < replay.plays.size() else ""
		hud.text = "REPLAY %sx  %s%s  [V exit%s]" % [str(replay.speed), lbl, "  (paused)" if replay.paused else "",
			", Space pause, Left/Right play, [ ] speed" if replay_viewer else ""]
		return
	if in_lobby():
		var who := "host: [3/5/7] size, [M] mode, [H] half length, " if is_server() else ""
		hud.text = "PRIVATE MATCH LOBBY   Invite code: %s\n%s\n[Enter] ready  (%s starts when everyone is ready)" % [lobby.code, lobby.summary(), who]
		return
	var clock_txt: String = "%s%dv%d %s" % ["CHAOSBALL " if match_mode == "chaosball" else "", match_size, match_size, series.clock.label()]
	if world.is_chaos():
		clock_txt += " | STREAK %d -> TD %d | BALL %.1fs" % [world.streak, world.streak_points(), maxf(0.0, T.PASS_CLOCK - world.hold_t)]
	if drill != null:
		clock_txt = drill.label()
	if world.phase == World.Phase.PRESNAP:
		clock_txt += " | PLAY %d" % int(ceil(series.clock.play_clock))
	if series.is_final():
		var w := series.winner()
		phase_name = "FINAL: HOME %d - AWAY %d  %s\n%s" % [series.score[0], series.score[1], "TIE" if w < 0 else ("HOME WINS" if w == 0 else "AWAY WINS"),
			"\n".join(summary_lines) if not summary_lines.is_empty() else "(no stats)"]
		if my_ranks != "":
			phase_name += "\nYOUR RANKS: " + my_ranks
		if ranked_line != "":
			phase_name += "\n" + ranked_line
		if xp_line != "":
			phase_name += "\n" + xp_line
		if achievement_line != "":
			phase_name += "\n" + achievement_line
	else:
		phase_name = "HOME %d - AWAY %d | %s | %s | %s | %s" % [series.score[0], series.score[1], clock_txt, situation, side, phase_name]
	var charge_txt := ("   %s %d%%" % ["KICK" if kicking() else "THROW", int(charge * 100)]) if charging else ""
	hud.text = charge_txt + "\n" + "%s   Yard: %.1f  Speed: %.1f yd/s  Stamina: %d%%%s" % [
		phase_name, m.position.y, m.speed(), int(m.stamina * 100), "  (WINDED)" if m.sprint_locked else ""]

func _build_environment() -> void:
	StadiumArt.build_environment(self)
	var q := ArtQuality.level()
	get_viewport().msaa_3d = Viewport.MSAA_4X if q == "high" else (Viewport.MSAA_2X if q == "medium" else Viewport.MSAA_DISABLED)

func _box(size: Vector3, center: Vector3, color: Color, n: String) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	mi.mesh = bm
	mi.position = center
	mi.name = n
	field_root.add_child(mi)

func _build_field() -> void:
	FieldArt.build(field_root, field, TEAM_COLORS)
	if pres:
		pres.rebuild(field_root)
