extends Node3D
## Local player: reads input, drives PlayerMotion sim, mirrors its position.

const PlayerMotion := preload("res://src/sim/player_motion.gd")

var motion: PlayerMotion

func setup(field, start: Vector2) -> void:
	motion = PlayerMotion.new(start, field)

func _ready() -> void:
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.4
	cap.height = 1.9
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.75, 0.2)
	cap.material = mat
	mi.mesh = cap
	mi.position.y = 0.95
	add_child(mi)
	_sync()

func read_input() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): v.y += 1
	if Input.is_key_pressed(KEY_S): v.y -= 1
	if Input.is_key_pressed(KEY_D): v.x += 1
	if Input.is_key_pressed(KEY_A): v.x -= 1
	return v

func _physics_process(delta: float) -> void:
	motion.step(read_input(), Input.is_key_pressed(KEY_SHIFT), delta)
	_sync()

func _sync() -> void:
	position = Vector3(motion.position.x, 0, -motion.position.y)
	if motion.speed() > 0.1:
		rotation.y = atan2(-motion.velocity.x, motion.velocity.y)
