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
const T := preload("res://src/sim/tuning.gd")
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
var charging := false
var charge := 0.0
var aim_point := Vector2(26, 45)
var ai := AI.new()
var last_whistle := ""
var series: Match
var my_id := -1          # the human's athlete (QB on offense, LB on defense)
var dead_t := 0.0
var auto_next := true
var los_marker: MeshInstance3D
var fd_marker: MeshInstance3D
var input_override = null   # tests/bots: Vector2 replaces keyboard movement
var net: NetSession
var net_tick := 0
var camera: Camera3D
var hud: Label

static func to_world(p: Vector2, h: float = 0.0) -> Vector3:
	return Vector3(p.x, h, -p.y)

func _ready() -> void:
	_build_environment()
	_build_field()
	_spawn_teams()
	_build_aim_visuals()
	series = Match.new(world)
	series.start(0, 25.0)
	world.event.connect(_on_world_event)
	_setup_net()
	los_marker = _marker(Color(0.2, 0.5, 1.0), "LOSMarker")
	fd_marker = _marker(Color(1.0, 0.85, 0.1), "FirstDownMarker")
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

func _spawn_teams() -> void:
	var cx: float = field.width / 2.0
	var R := Athlete.Role
	# Two-way athletes: [offense role, x offset, defense role, x offset]
	var pairs := [[R.C, 0.0, R.DL, -1.5], [R.QB, 0.0, R.LB, 0.0], [R.WR, -18.0, R.CB, -18.0], [R.WR, 18.0, R.CB, 18.0],
		[R.RB, 4.0, R.S, -8.0], [R.OL, -2.5, R.DL, 1.5], [R.OL, 2.5, R.S, 8.0]]
	for t in 2:
		for p in pairs:
			var a := world.add_two_way(t, p[0], cx + p[1], p[2], cx + p[3])
			var v := PlayerNode.new()
			v.name = "Athlete%d" % a.id
			v.setup(a, TEAM_COLORS[t])
			add_child(v)
			views.append(v)
	my_id = world.find_role(0, R.QB).id
	controlled_id = my_id
	player = views[controlled_id]
	ball_view = MeshInstance3D.new()
	ball_view.name = "Ball"
	var sm := SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.36
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.45, 0.25, 0.1)
	sm.material = bm
	ball_view.mesh = sm
	ball_view.scale = Vector3(1, 1, 1.7)
	add_child(ball_view)

func _build_aim_visuals() -> void:
	reticle = MeshInstance3D.new()
	reticle.name = "Reticle"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.6
	tm.outer_radius = 0.8
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(1, 1, 1, 0.8)
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.material = rm
	reticle.mesh = tm
	add_child(reticle)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(1, 0.9, 0.3)
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in ARC_DOTS:
		var d := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.08
		sm.height = 0.16
		sm.material = dm
		d.mesh = sm
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
	var v := Passing.solve_velocity(from, aim_point, charge)
	v += Vector3(qb.velocity.x, qb.velocity.y, 0) * T.THROW_INHERIT
	var tf := Passing.time_to_height(v, from.z, 0.0)
	for i in ARC_DOTS:
		var t := tf * float(i + 1) / ARC_DOTS
		var p := from + v * t + Vector3(0, 0, -0.5 * T.GRAVITY * t * t)
		arc_dots[i].position = Vector3(p.x, p.z, -p.y)
		arc_dots[i].visible = true

func _set_charging(on: bool) -> void:
	if on and world.ball.is_held_by(controlled_id) and not charging:
		charging = true
		charge = 0.0
	elif not on and charging:
		charging = false
		do_action({"a": "throw", "t": aim_point, "p": charge})

## All human actions go through here: local authority offline/host, sent to server as client.
func do_action(action: Dictionary) -> bool:
	if is_client():
		net.send_action(action)
		return true
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
	if not (args.has("host") or args.has("join")):
		return
	net = NetSession.new()
	net.name = "Net"
	add_child(net)
	var port := int(args.get("port", NetSession.DEFAULT_PORT))
	if args.has("host"):
		# First joiner gets the opponent's QB/LB pair, then alternate teams.
		var pool: Array = [world.find_role(1, Athlete.Role.LB).id]
		var t0 := []
		var t1 := []
		for a in world.athletes:
			if a.id == my_id or pool.has(a.id):
				continue
			(t0 if a.team == 0 else t1).append(a.id)
		for i in maxi(t0.size(), t1.size()):
			if i < t1.size(): pool.append(t1[i])
			if i < t0.size(): pool.append(t0[i])
		if args.has("playclock"):  # test/debug: shorten the first play clock
			series.clock.play_clock = float(args["playclock"])
		var err := net.host(port, pool)
		print("NET host on %d: %s" % [port, error_string(err)])
	else:
		var err := net.join(str(args["join"]), port)
		print("NET join %s:%d: %s" % [args["join"], port, error_string(err)])
		auto_next = false
		net.welcomed.connect(func(aid): my_id = aid; set_controlled(aid); print("NET welcomed as athlete %d" % aid))
		net.snapshot_received.connect(func(snap): Protocol.apply_snapshot(series, snap))
		net.event_received.connect(_on_world_event)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_set_charging(e.pressed)
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
		do_action({"a": "tackle"})


func _on_world_event(n: String, d: Dictionary) -> void:
	if n == "incomplete" and last_whistle == "":
		last_whistle = "INCOMPLETE"
	if n in ["tackle", "out_of_bounds", "breakup", "touchdown"]:
		last_whistle = n.replace("_", " ").to_upper()
	if n == "snap":
		last_whistle = ""
	if is_server():
		net.broadcast_event(n, d)
	# Offline convenience: follow the ball to the receiver. Online: fixed athlete (Gridiron parity).
	if net == null and n == "catch" and world.get_athlete(d["by"]).team == world.offense_team:
		set_controlled(d["by"])

func _marker(c: Color, n: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(field.width, 0.13, 0.25)
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = m
	mi.mesh = bm
	mi.name = n
	add_child(mi)
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
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_SPACE:
			world.snap()
		elif e.keycode == KEY_1:
			series.choose_try(1)
		elif e.keycode == KEY_2:
			series.choose_try(2)
		elif e.keycode == KEY_E:
			world.tackle(controlled_id)
		elif e.keycode == KEY_J:
			_set_charging(true)
		elif e.keycode == KEY_R and world.phase == World.Phase.DEAD:
			next_play()

func _physics_process(delta: float) -> void:
	if charging:
		charge = minf(1.0, charge + delta / T.THROW_CHARGE_TIME)
	var my_input := {"dir": read_input(), "sprint": Input.is_key_pressed(KEY_SHIFT)}
	if is_client():
		net.send_input(my_input["dir"], my_input["sprint"])   # server is authoritative; state arrives via snapshots
	else:
		_step_authoritative(delta, my_input)
	_render()

func _step_authoritative(delta: float, my_input: Dictionary) -> void:
	series.tick(delta)
	if world.phase == World.Phase.DEAD and auto_next and not series.is_final():
		dead_t += delta
		if dead_t >= NEXT_PLAY_DELAY:
			next_play()
	var humans: Array = [controlled_id]
	if is_server():
		humans += net.human_athletes()
		for pa in net.take_actions():
			Protocol.apply_action(series, pa[0], pa[1])
	var inputs := ai.think(world, humans)
	inputs[controlled_id] = my_input
	if is_server():
		for aid in net.inputs:
			inputs[aid] = net.inputs[aid]
	world.step(inputs, delta)
	if is_server():
		net_tick += 1
		if net_tick % SNAPSHOT_EVERY == 0:
			net.broadcast_snapshot(Protocol.encode_snapshot(series, net_tick))

func _render() -> void:
	for v in views:
		v.sync()
	var b = world.ball.position
	ball_view.position = Vector3(b.x, b.z, -b.y)
	_update_aim()
	_update_arc()
	los_marker.position = Vector3(field.width / 2.0, 0.0, -series.downs.los)
	fd_marker.position = Vector3(field.width / 2.0, 0.0, -series.downs.first_down_y)
	fd_marker.visible = not series.downs.is_goal_to_go()

func _process(delta: float) -> void:
	var target := player.global_position
	var desired := target + Vector3(0, 6, 9)
	camera.global_position = camera.global_position.lerp(desired, clampf(delta * 6.0, 0.0, 1.0))
	camera.look_at(target + Vector3(0, 1, -4))
	var m = player.athlete
	var my_team: int = world.get_athlete(my_id).team
	var side := "OFFENSE" if world.offense_team == my_team else "DEFENSE (E/RMB to tackle)"
	var phase_name: String = ["PRE-SNAP (Space to snap)", "LIVE", "DEAD"][world.phase]
	if world.offense_team != my_team and world.phase == World.Phase.PRESNAP:
		phase_name = "PRE-SNAP (Space: let them snap)"
	if world.phase == World.Phase.DEAD and last_whistle != "":
		phase_name = "%s at %.1f" % [last_whistle, world.dead_ball_spot.y]
	var situation: String = series.downs.label()
	if series.state == Match.State.TRY:
		situation = "TRY for %d (1: from the 3 / 2: from the 10)" % series.try_points
	var clock_txt: String = series.clock.label()
	if world.phase == World.Phase.PRESNAP:
		clock_txt += " | PLAY %d" % int(ceil(series.clock.play_clock))
	if series.is_final():
		var w := series.winner()
		phase_name = "FINAL: HOME %d - AWAY %d  %s" % [series.score[0], series.score[1], "TIE" if w < 0 else ("HOME WINS" if w == 0 else "AWAY WINS")]
	else:
		phase_name = "HOME %d - AWAY %d | %s | %s | %s | %s" % [series.score[0], series.score[1], clock_txt, situation, side, phase_name]
	var charge_txt := ("   THROW %d%%" % int(charge * 100)) if charging else ""
	hud.text = charge_txt + "\n" + "%s   Yard: %.1f  Speed: %.1f yd/s  Stamina: %d%%%s" % [
		phase_name, m.position.y, m.speed(), int(m.stamina * 100), "  (WINDED)" if m.sprint_locked else ""]

func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
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
	add_child(mi)

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
