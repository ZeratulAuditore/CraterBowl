extends Node3D
## View of one sim athlete. Mirrors position; owns no rules. Cosmetics are view-only.
##
## Perf contract (docs/optimization/README.md):
##   - Meshes/materials come from RenderCache (shared, low-poly). Never `.new()` them here.
##   - sync() runs once per physics tick (pose + interpolation target);
##     interpolate(f) runs once per render frame and only moves the root.

const Cos := preload("res://src/sim/cosmetics.gd")
const RC := preload("res://src/game/render_cache.gd")
## A view that moves more than this (yards) in one tick teleported (new play,
## replay seek, swap): snap instead of gliding across the field.
const TELEPORT_DIST := 2.0

var athlete  # sim athlete
var color := Color(0.9, 0.75, 0.2)
var body: MeshInstance3D
var trim_band: MeshInstance3D
var helmet: MeshInstance3D
var stripe: MeshInstance3D
var number_front: Label3D
var number_back: Label3D
var number_text := ""
var trim_color := Color.WHITE
var look := {}
var celebrate_kind := "none"
var celebrate_t := 0.0
# Render interpolation state: last two sim poses.
var _prev_pos := Vector3.ZERO
var _cur_pos := Vector3.ZERO
var _prev_yaw := 0.0
var _cur_yaw := 0.0
var _has_pose := false

func setup(a, c: Color) -> void:
	athlete = a
	color = c

func _mat(c: Color) -> StandardMaterial3D:
	return RC.mat(c)

func _ready() -> void:
	body = MeshInstance3D.new()
	body.mesh = RC.capsule(0.4, 1.9)
	body.material_override = _mat(color)
	body.position.y = 0.95
	add_child(body)
	trim_band = MeshInstance3D.new()
	trim_band.mesh = RC.cylinder(0.42, 0.12)
	trim_band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trim_band.position.y = 0.1
	body.add_child(trim_band)
	helmet = MeshInstance3D.new()
	helmet.mesh = RC.sphere(0.28, 0.5)
	helmet.position.y = 0.85
	body.add_child(helmet)
	stripe = MeshInstance3D.new()
	stripe.mesh = RC.box(Vector3(0.08, 0.06, 0.56))
	stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stripe.position.y = 0.27
	helmet.add_child(stripe)
	number_front = _number_label(0.42)
	number_back = _number_label(-0.42)
	apply_look(Cos.DEFAULT_LOOK.merged({"number": (athlete.id % 90) + 10}, true))
	sync()

func _number_label(z: float) -> Label3D:
	var l := Label3D.new()
	l.font_size = 64
	l.pixel_size = 0.006
	l.position = Vector3(0, 0.35, z)
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if z < 0.0:
		l.rotation.y = PI
	body.add_child(l)
	return l

## Apply a (sanitized) look. Purely visual.
func apply_look(lk: Dictionary) -> void:
	look = Cos.sanitize_look(lk)
	trim_color = Cos.color_of("trim", look["trim"])
	trim_band.material_override = _mat(trim_color)
	helmet.material_override = _mat(color.darkened(0.2))
	stripe.material_override = _mat(Cos.color_of("helmet", look["helmet"]))
	number_text = str(int(look["number"]))
	number_front.text = number_text
	number_back.text = number_text
	number_front.modulate = trim_color
	number_back.modulate = trim_color

func celebrate(kind: String) -> void:
	if kind != "none":
		celebrate_kind = kind
		celebrate_t = 1.5

func is_celebrating() -> bool:
	return celebrate_t > 0.0

## Per physics tick: body pose + a new interpolation target from the sim athlete.
func sync() -> void:
	var yaw := _cur_yaw
	if athlete.speed() > 0.1:
		yaw = atan2(-athlete.velocity.x, athlete.velocity.y)
	place(Vector3(athlete.position.x, 0, -athlete.position.y), yaw)
	var down: bool = athlete.is_diving() or athlete.is_grounded()
	body.rotation = Vector3(-PI / 2.0 if down else 0.0, 0, 0)
	body.position.y = 0.4 if down else 0.95
	if celebrate_t > 0.0:
		celebrate_t = maxf(0.0, celebrate_t - 1.0 / 60.0)
		var k := 1.5 - celebrate_t
		match celebrate_kind:
			"spin": body.rotation.y = k * TAU * 2.0
			"hop": body.position.y = 0.95 + absf(sin(k * 6.0)) * 0.9
			"flip": body.rotation.x = k * TAU / 1.5

## Record a new sim pose. Big jumps (formation reset, replay seek) snap.
func place(p: Vector3, yaw: float) -> void:
	if not _has_pose or p.distance_to(_cur_pos) > TELEPORT_DIST:
		_prev_pos = p
		_prev_yaw = yaw
		_has_pose = true
	else:
		_prev_pos = _cur_pos
		_prev_yaw = _cur_yaw
	_cur_pos = p
	_cur_yaw = yaw
	position = p
	rotation.y = yaw

## Per render frame: f = Engine.get_physics_interpolation_fraction() in [0, 1].
func interpolate(f: float) -> void:
	position = _prev_pos.lerp(_cur_pos, f)
	rotation.y = lerp_angle(_prev_yaw, _cur_yaw, f)

## Latest sim (or replay) pose this view is heading to; `position` may lag it by < 1 tick.
func target_position() -> Vector3:
	return _cur_pos
