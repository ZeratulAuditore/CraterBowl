extends Node3D
## View of one sim athlete. Mirrors position; owns no rules.

var athlete  # sim athlete
var color := Color(0.9, 0.75, 0.2)

func setup(a, c: Color) -> void:
	athlete = a
	color = c

func _ready() -> void:
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.4
	cap.height = 1.9
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	cap.material = mat
	mi.mesh = cap
	mi.position.y = 0.95
	add_child(mi)
	sync()

func sync() -> void:
	position = Vector3(athlete.position.x, 0, -athlete.position.y)
	if athlete.speed() > 0.1:
		rotation.y = atan2(-athlete.velocity.x, athlete.velocity.y)
