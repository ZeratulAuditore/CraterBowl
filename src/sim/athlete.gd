extends "res://src/sim/player_motion.gd"
## An athlete on the field: motion + identity.

enum Role { QB, C, WR, RB, LB, CB, S, OL, DL }

var id: int = 0
var team: int = 0
var role: Role = Role.WR

func _init(p_id: int = 0, p_team: int = 0, p_role: Role = Role.WR, start: Vector2 = Vector2.ZERO, f = null) -> void:
	super(start, f)
	id = p_id
	team = p_team
	role = p_role
