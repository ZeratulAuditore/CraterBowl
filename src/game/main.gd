extends Node3D
## Builds the field, spawns the local player and camera. Presentation only:
## rules live in src/sim. Sim (x, y) yards maps to 3D (x, 0, -y).

const World := preload("res://src/sim/world.gd")
const Athlete := preload("res://src/sim/athlete.gd")
const PlayerNode := preload("res://src/game/player.gd")

const TEAM_COLORS := [Color(0.95, 0.75, 0.15), Color(0.3, 0.8, 0.95)]

var world := World.new()
const Field := preload("res://src/sim/field.gd")
var field: Field = world.field
var controlled_id := -1
var views: Array = []
var player: Node3D  # view of the controlled athlete
var ball_view: MeshInstance3D
var camera: Camera3D
var hud: Label

static func to_world(p: Vector2, h: float = 0.0) -> Vector3:
	return Vector3(p.x, h, -p.y)

func _ready() -> void:
	_build_environment()
	_build_field()
	_spawn_teams()
	world.setup_formation(25.0)
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
	var offense := [[R.C, 0.0], [R.QB, 0.0], [R.WR, -18.0], [R.WR, 18.0], [R.RB, 4.0], [R.OL, -2.5], [R.OL, 2.5]]
	var defense := [[R.DL, -1.5], [R.DL, 1.5], [R.LB, 0.0], [R.CB, -18.0], [R.CB, 18.0], [R.S, -8.0], [R.S, 8.0]]
	for t in 2:
		for e in (offense if t == 0 else defense):
			var a := world.add_athlete(t, e[0], Vector2(cx + e[1], 0))
			var v := PlayerNode.new()
			v.name = "Athlete%d" % a.id
			v.setup(a, TEAM_COLORS[t])
			add_child(v)
			views.append(v)
	controlled_id = world.find_role(0, R.QB).id
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

func read_input() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): v.y += 1
	if Input.is_key_pressed(KEY_S): v.y -= 1
	if Input.is_key_pressed(KEY_D): v.x += 1
	if Input.is_key_pressed(KEY_A): v.x -= 1
	return v

func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_SPACE:
			world.snap()
		elif e.keycode == KEY_R:
			world.setup_formation(world.los_y)

func _physics_process(delta: float) -> void:
	world.step({controlled_id: {"dir": read_input(), "sprint": Input.is_key_pressed(KEY_SHIFT)}}, delta)
	for v in views:
		v.sync()
	var b = world.ball.position
	ball_view.position = Vector3(b.x, b.z, -b.y)

func _process(delta: float) -> void:
	var target := player.global_position
	var desired := target + Vector3(0, 6, 9)
	camera.global_position = camera.global_position.lerp(desired, clampf(delta * 6.0, 0.0, 1.0))
	camera.look_at(target + Vector3(0, 1, -4))
	var m = player.athlete
	var phase_name: String = ["PRE-SNAP (Space to snap)", "LIVE", "DEAD (R to reset)"][world.phase]
	hud.text = "%s   Yard: %.1f  Speed: %.1f yd/s  Stamina: %d%%%s" % [
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
