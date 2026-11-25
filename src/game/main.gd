extends Node3D
## Builds the field, spawns the local player and camera. Presentation only:
## rules live in src/sim. Sim (x, y) yards maps to 3D (x, 0, -y).

const Field := preload("res://src/sim/field.gd")
const PlayerNode := preload("res://src/game/player.gd")

var field := Field.new()
var player: Node3D
var camera: Camera3D
var hud: Label

static func to_world(p: Vector2, h: float = 0.0) -> Vector3:
	return Vector3(p.x, h, -p.y)

func _ready() -> void:
	_build_environment()
	_build_field()
	player = PlayerNode.new()
	player.name = "Player"
	player.setup(field, Vector2(field.width / 2.0, 25.0))
	add_child(player)
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

func _process(delta: float) -> void:
	var target := player.global_position
	var desired := target + Vector3(0, 6, 9)
	camera.global_position = camera.global_position.lerp(desired, clampf(delta * 6.0, 0.0, 1.0))
	camera.look_at(target + Vector3(0, 1, -4))
	var m = player.motion
	hud.text = "Yard: %.1f  Speed: %.1f yd/s  Stamina: %d%%%s" % [
		m.position.y, m.speed(), int(m.stamina * 100), "  (WINDED)" if m.sprint_locked else ""]

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
