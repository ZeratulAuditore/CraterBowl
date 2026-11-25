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
var spin_t := 0.0          # > 0 while spinning
var spin_dir := 0          # -1 left, +1 right (relative to facing)
var spin_cd := 0.0
var spin_speed := 0.0      # forward speed carried through the spin
var emote_cd := 0.0        # taunt rate limit (cosmetic)
var set_lock := false    # pre-snap: held in stance until break_stance (defense)

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

func is_spinning() -> bool:
	return spin_t > 0.0

func can_act() -> bool:
	return not is_diving() and not is_grounded()

## Spin move: side = -1 left / +1 right of facing. Can't chain spins (cooldown).
func start_spin(side: int) -> bool:
	if not can_act() or is_spinning() or spin_cd > 0.0 or side == 0:
		return false
	spin_t = T.SPIN_TIME
	spin_dir = signi(side)
	spin_speed = maxf(velocity.dot(facing), 0.0) * T.SPIN_SPEED_KEEP
	spin_cd = T.SPIN_TIME + T.SPIN_COOLDOWN
	return true

## Turn toward dir without moving (stance-locked athletes can still look around).
func face(dir: Vector2) -> void:
	velocity = Vector2.ZERO
	if dir.length_squared() > 0.0001:
		facing = dir.normalized()

func start_dive() -> bool:
	if not can_act():
		return false
	dive_t = T.DIVE_TIME
	spin_t = 0.0
	return true

func reset_state() -> void:
	dive_t = 0.0
	recover_t = 0.0
	engaged_with = -1
	engage_t = 0.0
	immune_t = 0.0
	spin_t = 0.0
	spin_dir = 0
	spin_cd = 0.0
	velocity = Vector2.ZERO

func step(input: Vector2, wants_sprint: bool, dt: float) -> void:
	spin_cd = maxf(0.0, spin_cd - dt)
	emote_cd = maxf(0.0, emote_cd - dt)
	if spin_t > 0.0 and can_act():
		# Committed: keep momentum along facing, drift toward the spin side.
		spin_t -= dt
		if spin_t < 0.0001:   # float dust: a 0.4s spin lasts exactly 24 ticks
			spin_t = 0.0
		var fwd := facing * spin_speed
		var side := Vector2(facing.y, -facing.x) * float(spin_dir)   # +1 = right of facing
		velocity = velocity.move_toward(fwd + side * T.SPIN_SIDESTEP, T.ACCEL * 2.0 * dt)
		position = field.clamp_playable(position + velocity * dt)
		return
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
