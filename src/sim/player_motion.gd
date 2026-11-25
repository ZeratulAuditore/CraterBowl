extends RefCounted
## Deterministic player movement + stamina. Input-driven, no Node deps.

const T := preload("res://src/sim/tuning.gd")
const Field := preload("res://src/sim/field.gd")

var position := Vector2.ZERO
var velocity := Vector2.ZERO
var facing := Vector2(0, 1)
var stamina := 1.0
var sprint_locked := false
var field: Field

func _init(start: Vector2 = Vector2.ZERO, f: Field = null) -> void:
	position = start
	field = f if f != null else Field.new()

func is_sprinting(wants_sprint: bool, input: Vector2) -> bool:
	return wants_sprint and not sprint_locked and stamina > 0.0 and input.length_squared() > 0.0001

## Advance by dt. input is a direction (any length; clamped to unit).
func step(input: Vector2, wants_sprint: bool, dt: float) -> void:
	var dir := input.limit_length(1.0)
	var sprinting := is_sprinting(wants_sprint, dir)
	var max_speed := T.SPRINT_SPEED if sprinting else T.RUN_SPEED
	var target := dir * max_speed
	var rate := T.ACCEL if dir.length_squared() > 0.0001 else T.DECEL
	velocity = velocity.move_toward(target, rate * dt)
	position = field.clamp_playable(position + velocity * dt)
	if dir.length_squared() > 0.0001:
		facing = dir.normalized()

	if sprinting:
		stamina = maxf(0.0, stamina - T.STAMINA_DRAIN * dt)
		if stamina <= 0.0:
			sprint_locked = true
	else:
		stamina = minf(1.0, stamina + T.STAMINA_REGEN * dt)
		if sprint_locked and stamina >= T.STAMINA_LOCKOUT_RECOVER:
			sprint_locked = false

func speed() -> float:
	return velocity.length()
