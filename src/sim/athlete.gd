extends "res://src/sim/player_motion.gd"
## An athlete on the field: motion + identity + dive/recover state.

enum Role { QB, C, WR, RB, LB, CB, S, OL, DL }

var id: int = 0
var team: int = 0
var role: Role = Role.WR
var dive_t := 0.0
var recover_t := 0.0
var home_x := 0.0          # formation x for the current side
var off_role: Role = Role.WR
var def_role: Role = Role.LB
var off_x := 0.0
var def_x := 0.0
var engaged_with := -1   # id of blocker (on defender) or defender (on blocker)
var engage_t := 0.0
var immune_t := 0.0

func _init(p_id: int = 0, p_team: int = 0, p_role: Role = Role.WR, start: Vector2 = Vector2.ZERO, f = null) -> void:
	super(start, f)
	id = p_id
	team = p_team
	role = p_role
	home_x = start.x
	off_role = p_role
	def_role = p_role
	off_x = start.x
	def_x = start.x

## Switch to this side's role + formation x.
func set_side(on_offense: bool) -> void:
	role = off_role if on_offense else def_role
	home_x = off_x if on_offense else def_x

func is_diving() -> bool:
	return dive_t > 0.0

func is_grounded() -> bool:
	return recover_t > 0.0

func can_act() -> bool:
	return not is_diving() and not is_grounded()

func start_dive() -> bool:
	if not can_act():
		return false
	dive_t = T.DIVE_TIME
	return true

func reset_state() -> void:
	dive_t = 0.0
	recover_t = 0.0
	engaged_with = -1
	engage_t = 0.0
	immune_t = 0.0
	velocity = Vector2.ZERO

func step(input: Vector2, wants_sprint: bool, dt: float) -> void:
	if dive_t > 0.0:
		dive_t -= dt
		velocity = facing * T.DIVE_SPEED
		position = field.clamp_playable(position + velocity * dt)
		if dive_t <= 0.0:
			dive_t = 0.0
			recover_t = T.DIVE_RECOVER
		return
	if recover_t > 0.0:
		recover_t = maxf(0.0, recover_t - dt)
		velocity = velocity.move_toward(Vector2.ZERO, T.DECEL * 2.0 * dt)
		position = field.clamp_playable(position + velocity * dt)
		return
	super.step(input, wants_sprint, dt)
