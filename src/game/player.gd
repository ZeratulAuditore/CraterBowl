extends Node3D
## View of one sim athlete. Mirrors position; owns no rules. Cosmetics are view-only.

const Cos := preload("res://src/sim/cosmetics.gd")

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

func setup(a, c: Color) -> void:
	athlete = a
	color = c

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m

func _ready() -> void:
	body = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.4
	cap.height = 1.9
	cap.material = _mat(color)
	body.mesh = cap
	body.position.y = 0.95
	add_child(body)
	trim_band = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.42
	cyl.height = 0.12
	trim_band.mesh = cyl
	trim_band.position.y = 0.1
	body.add_child(trim_band)
	helmet = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.28
	sph.height = 0.5
	helmet.mesh = sph
	helmet.position.y = 0.85
	body.add_child(helmet)
	stripe = MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.08, 0.06, 0.56)
	stripe.mesh = bx
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

func sync() -> void:
	position = Vector3(athlete.position.x, 0, -athlete.position.y)
	var down: bool = athlete.is_diving() or athlete.is_grounded()
	body.rotation = Vector3(-PI / 2.0 if down else 0.0, 0, 0)
	body.position.y = 0.4 if down else 0.95
	if athlete.speed() > 0.1:
		rotation.y = atan2(-athlete.velocity.x, athlete.velocity.y)
	if celebrate_t > 0.0:
		celebrate_t = maxf(0.0, celebrate_t - 1.0 / 60.0)
		var k := 1.5 - celebrate_t
		match celebrate_kind:
			"spin": body.rotation.y = k * TAU * 2.0
			"hop": body.position.y = 0.95 + absf(sin(k * 6.0)) * 0.9
			"flip": body.rotation.x = k * TAU / 1.5
