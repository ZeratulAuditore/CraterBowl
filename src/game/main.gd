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
const MatchConfig := preload("res://src/sim/match_config.gd")
const Lobby := preload("res://src/net/lobby.gd")
const Drills := preload("res://src/sim/drills.gd")
const Stats := preload("res://src/sim/stats.gd")
const Leaderboard := preload("res://src/sim/leaderboard.gd")
const Ranked := preload("res://src/sim/ranked.gd")
const Cosmetics := preload("res://src/sim/cosmetics.gd")
const Replay := preload("res://src/sim/replay.gd")
const MMServer := preload("res://src/net/mm_server.gd")
const MMClient := preload("res://src/net/mm_client.gd")
const InviteCode := preload("res://src/net/invite_code.gd")
const T := preload("res://src/sim/tuning.gd")
const RC := preload("res://src/game/render_cache.gd")
const GfxQuality := preload("res://src/game/gfx_quality.gd")
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
var arc_mm: MultiMeshInstance3D   # throw-arc preview: one draw call for all dots
var sun: DirectionalLight3D
var quality := GfxQuality.Level.MEDIUM
# Render interpolation for the ball (views interpolate themselves; see player.gd).
var _ball_prev := Vector3.ZERO
var _ball_cur := Vector3.ZERO
var _route_key := 0          # last drawn route-art state; rebuild only when it changes
var _hud_text := ""
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
var replay := Replay.new()
var replay_active := false      # views show replay frames instead of the live sim
var replay_viewer := false      # --replay=FILE standalone viewer
var replay_dir := "user://replays"
var saved_replay := ""
var my_ranks := ""
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

static func to_world(p: Vector2, h: float = 0.0) -> Vector3:
	return Vector3(p.x, h, -p.y)

func _ready() -> void:
	_build_environment()
	_build_ball_view()
	_build_aim_visuals()
	var args := _cli_args()
	quality = GfxQuality.parse(str(args["quality"]), GfxQuality.auto_level()) if args.has("quality") else GfxQuality.auto_level()
	GfxQuality.apply(quality, sun, get_viewport())
	if args.has("leaderboard-file"):
		leaderboard_path = str(args["leaderboard-file"])
	if args.has("ranked-file"):
		ranked_path = str(args["ranked-file"])
	if args.has("name"):
		player_name = str(args["name"]).strip_edges().left(16)
	ranked_match = args.has("ranked")
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
	route_lines.material_override = RC.mat(Color.WHITE, true, true)
	route_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	series = Match.new(world)
	series.start(0, Drills.LOS if drill != null else -1.0)
	world.event.connect(_on_world_event)
	stats = Stats.new()
	stats.attach(world, owner_name)
	replay = Replay.new()
	replay.attach(world)
	replay.meta = {"size": match_size, "mode": match_mode}
	replay_active = false
	summary_lines = []
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
	for a in world.athletes:
		var v := PlayerNode.new()
		v.name = "Athlete%d" % a.id
		v.setup(a, TEAM_COLORS[a.team])
		athlete_root.add_child(v)
		views.append(v)
	my_id = drill_me if drill_me >= 0 else roster.auto_assign(LOCAL_PLAYER)
	controlled_id = my_id
	player = views[controlled_id]

func _build_ball_view() -> void:
	ball_view = MeshInstance3D.new()
	ball_view.name = "Ball"
	ball_view.mesh = RC.sphere(0.18, 0.36)
	ball_view.material_override = RC.mat(Color(0.45, 0.25, 0.1))
	ball_view.scale = Vector3(1, 1, 1.7)
	add_child(ball_view)

func _build_aim_visuals() -> void:
	reticle = MeshInstance3D.new()
	reticle.name = "Reticle"
	reticle.mesh = RC.torus(0.6, 0.8)
	reticle.material_override = RC.mat(Color(1, 1, 1, 0.8), true)
	reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(reticle)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = RC.sphere(0.08)
	mm.instance_count = ARC_DOTS
	mm.visible_instance_count = 0
	arc_mm = MultiMeshInstance3D.new()
	arc_mm.name = "ThrowArc"
	arc_mm.multimesh = mm
	arc_mm.material_override = RC.mat(Color(1, 0.9, 0.3), true)
	arc_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(arc_mm)

## True while the throw-arc preview is visible (tests + HUD).
func arc_shown() -> bool:
	return arc_mm.multimesh.visible_instance_count > 0

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
		arc_mm.multimesh.visible_instance_count = 0
		return
	var from := Vector3(qb.position.x, qb.position.y, T.RELEASE_HEIGHT)
	var v := Passing.solve_velocity(from, aim_point, charge, world.gravity(), lob_held())
	v += Vector3(qb.velocity.x, qb.velocity.y, 0) * T.THROW_INHERIT
	var tf := Passing.time_to_height(v, from.z, 0.0, world.gravity())
	for i in ARC_DOTS:
		var t := tf * float(i + 1) / ARC_DOTS
		var p := from + v * t + Vector3(0, 0, -0.5 * world.gravity() * t * t)
		arc_mm.multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(p.x, p.z, -p.y)))
	arc_mm.multimesh.visible_instance_count = ARC_DOTS

func _set_charging(on: bool) -> void:
	if on and world.ball.is_held_by(controlled_id) and not charging:
		charging = true
		charge = 0.0
	elif not on and charging:
		charging = false
		do_action({"a": "throw", "t": aim_point, "p": charge, "lob": lob_held()})

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

## Every machine credits only its own player's local profile.
func _apply_award(xp: Dictionary) -> void:
	var me := owner_name(my_id) if not is_client() else player_name
	if not xp.has(me):
		return
	var gained := profile.add_xp(int(xp[me]))
	profile.save(profile_path)
	xp_line = "XP +%d (Level %d%s)" % [int(xp[me]), profile.level(), " - LEVEL UP!" if gained > 0 else ""]

func _on_match_event(n: String, _d: Dictionary) -> void:
	if n == "final" and drill == null:
		saved_replay = _save_replay()
		print("REPLAY saved: %s" % saved_replay)
	if n == "final":
		if not is_client() and drill == null:
			var awards := _match_awards()
			_apply_award(awards)
			if is_server():
				net.broadcast_event("awards", {"xp": awards})
			my_ranks = _record_leaderboard()
			if ranked_match:
				var r := _record_ranked()
				var rk := Ranked.new()
				rk.load_file(ranked_path)
				profile.season_rewards = rk.rewards.get(owner_name(my_id), [])
				profile.save(profile_path)
				ranked_line = _ranked_text(r)
				print("RANKED: %s" % str(r))
				if is_server():
					net.broadcast_event("ranked", r)
		summary_lines = stats.summary_lines()
		print("MATCH SUMMARY:\n  " + "\n  ".join(summary_lines))
		if is_server():
			net.broadcast_event("summary", {"lines": summary_lines})

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
		ranked_match = m.get("mode", "") == "competitive"
		pending_teams = m.get("teams", {}) if m.get("teams") is Dictionary else {}
		var port := 25000 + randi() % 5000
		var code := _host_game(port, {"start_when_ready": true, "expected": int(m.get("expected", 2)),
			"size": int(m.get("size", 7)), "advertise": advertise})
		lobby.settings["half_minutes"] = 5
		print("QUEUE matched (%s): hosting %s" % [m.get("mode", "?"), code])
		mm_client.send_hosting(code))
	mm_client.join_match.connect(func(code):
		print("QUEUE matched: joining %s" % code)
		_join_game(code, 0, {"auto_ready": true}))
	var rk := Ranked.new()
	rk.load_file(ranked_path)
	var err := mm_client.queue_up(addr, mm_port, mode, MatchConfig.normalize(args.get("size", 7)),
		float(args.get("rating", rk.rating(player_name))), player_name)
	print("QUEUE %s via %s:%d: %s" % [mode, addr, mm_port, error_string(err)])

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
		return true
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
		predictor.reconcile(me, int(snap.get("ack", {}).get(my_id, 0)))

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
	if n == "incomplete" and last_whistle == "":
		last_whistle = "INCOMPLETE"
	if n in ["tackle", "out_of_bounds", "breakup", "touchdown", "explode"]:
		last_whistle = n.replace("_", " ").to_upper()
	if n == "ranked":
		ranked_line = _ranked_text(d)
	if n == "looks" and d.get("looks") is Dictionary:
		looks = d["looks"]
		_apply_looks()
	if n == "awards" and d.get("xp") is Dictionary:
		_apply_award(d["xp"])
	if n == "touchdown":
		var cid: int = d.get("carrier", -1)
		if cid >= 0 and cid < views.size():
			views[cid].celebrate(str(looks.get(cid, {}).get("celebration", "none")))
	if n == "summary":
		summary_lines = d.get("lines", []) if d.get("lines") is Array else []
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
	# Offline: take control of whoever on your team just took the ball away.
	if net == null and n in ["interception", "recovery"] and world.get_athlete(d["by"]).team == world.get_athlete(my_id).team:
		set_controlled(d["by"])

func _marker(c: Color, n: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = RC.box(Vector3(field.width, 0.13, 0.25))
	mi.material_override = RC.mat(c, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = n
	field_root.add_child(mi)
	return mi

func next_play() -> void:
	series.next_play()
	dead_t = 0.0
	last_whistle = ""
	set_controlled(my_id)

func set_controlled(id: int) -> void:
	controlled_id = id
	player = views[id]

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
			do_action({"a": "try", "n": 1})
		KEY_2:
			do_action({"a": "try", "n": 2})
		KEY_E:
			do_action({"a": "tackle"})
		KEY_J:
			_set_charging(true)
		KEY_Q:
			var i := (Routes.PLAY_NAMES.find(world.play_name) + 1) % Routes.PLAY_NAMES.size()
			do_action({"a": "play", "p": Routes.PLAY_NAMES[i]})
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
			me.step(my_input["dir"], my_input["sprint"], delta)
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
	ai.presnap_tick(world, humans, delta, series.downs.down, series.downs.distance())
	var inputs := ai.think(world, humans)
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
		views[i].place(Vector3(pos[i].x, 0, -pos[i].y), views[i]._cur_yaw)
	var b: Vector3 = smp["ball"]
	_place_ball(Vector3(b.x, b.z, -b.y))

## Per physics tick: copy sim state into view targets. Cheap, change-driven work only.
func _render() -> void:
	for v in views:
		v.sync()
	var b = world.ball.position
	_place_ball(Vector3(b.x, b.z, -b.y))
	los_marker.position = Vector3(field.width / 2.0, 0.0, -series.downs.los)
	fd_marker.position = Vector3(field.width / 2.0, 0.0, -series.downs.first_down_y)
	fd_marker.visible = not series.downs.is_goal_to_go()
	_draw_routes()

## Ball interpolation target (same teleport rule as athlete views).
func _place_ball(p: Vector3) -> void:
	_ball_prev = p if p.distance_to(_ball_cur) > PlayerNode.TELEPORT_DIST * 2.0 else _ball_cur
	_ball_cur = p
	ball_view.position = p

## Per display frame: draw between the last two sim ticks so motion is smooth at
## any refresh rate (60 Hz sim on a 144 Hz screen, or a frame that ran 2 ticks).
func _render_frame() -> void:
	var f := Engine.get_physics_interpolation_fraction()
	for v in views:
		v.interpolate(f)
	ball_view.position = _ball_prev.lerp(_ball_cur, f)
	_update_aim()
	_update_arc()

## Presnap route art for your own offense only (the defense never sees it).
func _draw_routes() -> void:
	var me = world.get_athlete(my_id)
	if me == null or world.phase != World.Phase.PRESNAP or me.team != world.offense_team or world.route_of.is_empty():
		if _route_key != 0:
			route_mesh.clear_surfaces()
			_route_key = 0
		return
	# Rebuilding an ImmediateMesh re-uploads it to the GPU: only do it when the art changes.
	var key_src := [my_id, field.width, world.route_of]
	for id in world.route_of:
		key_src.append(world.get_athlete(id).position)
	var key := hash(key_src)
	if key == _route_key:
		return
	_route_key = key
	route_mesh.clear_surfaces()
	route_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for id in world.route_of:
		var a = world.get_athlete(id)
		var pts: Array = [a.position] + Routes.path_for(world.route_of[id], a.position, field.width)
		route_mesh.surface_set_color(Color(1.0, 0.95, 0.3) if id != my_id else Color(0.3, 1.0, 0.5))
		for k in range(pts.size() - 1):
			route_mesh.surface_add_vertex(Vector3(pts[k].x, 0.15, -pts[k].y))
			route_mesh.surface_add_vertex(Vector3(pts[k + 1].x, 0.15, -pts[k + 1].y))
	route_mesh.surface_end()

func _process(delta: float) -> void:
	_render_frame()
	var target := player.global_position
	var desired := target + Vector3(0, 6, 9)
	# Exponential smoothing: same feel at 30, 60 or 144 fps (delta*k lerp is not).
	camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-6.0 * delta))
	camera.look_at(target + Vector3(0, 1, -4))
	var m = player.athlete
	var my_team: int = world.get_athlete(my_id).team
	var side := "OFFENSE" if world.offense_team == my_team else "DEFENSE (E/RMB to tackle)"
	side = "%s %s [TAB pos, T team]" % [roster.label(roster.slot_of_athlete(my_id)), side]
	if world.offense_team == my_team:
		side += " | PLAY: %s [Q]%s" % [world.play_name, (" | ROUTE: %s [F]" % world.route_of[my_id]) if world.route_of.has(my_id) else ""]
	var phase_name: String = ["PRE-SNAP (Space to snap)", "LIVE", "DEAD"][world.phase]
	if world.offense_team != my_team and world.phase == World.Phase.PRESNAP:
		phase_name = "PRE-SNAP (Space: let them snap)"
	if world.phase == World.Phase.DEAD and last_whistle != "":
		phase_name = "%s at %.1f" % [last_whistle, world.dead_ball_spot.y]
	var situation: String = series.downs.label()
	if series.state == Match.State.TRY:
		situation = "TRY for %d (1: from the 3 / 2: from the 10)" % series.try_points
	banner_t = maxf(0.0, banner_t - delta)
	if banner_t > 0.0:
		phase_name = banner + "  " + phase_name
	if searching():
		hud.text = "SEARCHING FOR A %s MATCH..." % str(_cli_args().get("queue", "")).to_upper()
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
	else:
		phase_name = "HOME %d - AWAY %d | %s | %s | %s | %s" % [series.score[0], series.score[1], clock_txt, situation, side, phase_name]
	var charge_txt := ("   THROW %d%%" % int(charge * 100)) if charging else ""
	hud.text = charge_txt + "\n" + "%s   Yard: %.1f  Speed: %.1f yd/s  Stamina: %d%%%s" % [
		phase_name, m.position.y, m.speed(), int(m.stamina * 100), "  (WINDED)" if m.sprint_locked else ""]

func _build_environment() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.03, 0.08)  # night sky, lunar stadium vibe
	e.ambient_light_color = Color(0.6, 0.65, 0.8)
	e.ambient_light_energy = 0.5
	env.environment = e
	add_child(env)

## Field geometry is static: boxes are batched into one mesh per color (a handful of
## draw calls instead of ~30) and never cast shadows (they are flat on the ground).
var _field_batches := {}   # Color -> [verts, normals, indices]

func _box(size: Vector3, center: Vector3, color: Color, _n: String) -> void:
	if not _field_batches.has(color):
		_field_batches[color] = [PackedVector3Array(), PackedVector3Array(), PackedInt32Array()]
	var batch: Array = _field_batches[color]
	var arr := RC.box(size).get_mesh_arrays()
	var base: int = batch[0].size()
	for v in arr[Mesh.ARRAY_VERTEX]:
		batch[0].append(v + center)
	batch[1].append_array(arr[Mesh.ARRAY_NORMAL])
	for i in arr[Mesh.ARRAY_INDEX]:
		batch[2].append(base + i)

func _flush_field() -> void:
	var k := 0
	for color in _field_batches:
		var b: Array = _field_batches[color]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = b[0]
		arrays[Mesh.ARRAY_NORMAL] = b[1]
		arrays[Mesh.ARRAY_INDEX] = b[2]
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		am.set_meta("tris", b[2].size() / 3)
		var mi := MeshInstance3D.new()
		mi.name = "FieldBatch%d" % k
		mi.mesh = am
		mi.material_override = RC.mat(color)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		field_root.add_child(mi)
		k += 1
	_field_batches = {}

func _build_field() -> void:
	var total := field.length + field.endzone_depth * 2.0
	# Turf (whole playing surface)
	_box(Vector3(field.width, 0.1, total), Vector3(field.width / 2, -0.05, -field.length / 2),
		Color(0.12, 0.42, 0.22), "Turf")
	# End zones
	_box(Vector3(field.width, 0.11, field.endzone_depth), to_world(Vector2(field.width / 2, -field.endzone_depth / 2), -0.04),
		Color(0.15, 0.3, 0.65), "EndZoneA")
	_box(Vector3(field.width, 0.11, field.endzone_depth), to_world(Vector2(field.width / 2, field.length + field.endzone_depth / 2), -0.04),
		Color(0.65, 0.25, 0.15), "EndZoneB")
	# Yard lines every 5 yards, thicker at goal lines
	for yd in range(0, int(field.length) + 1, 5):
		var w := 0.4 if yd == 0 or yd == int(field.length) else 0.15
		_box(Vector3(field.width, 0.12, w), to_world(Vector2(field.width / 2, yd), -0.03), Color(0.95, 0.95, 0.95), "Line%d" % yd)
	# Sidelines
	for x in [0.0, field.width]:
		_box(Vector3(0.3, 0.12, total), Vector3(x, -0.03, -field.length / 2), Color.WHITE, "Sideline")
	_flush_field()
