extends RefCounted
## Ball state. Position is 3D in sim space: (x, y) field plane, z = height (yards).

enum State { HELD, IN_FLIGHT, LOOSE, DEAD }

var state: State = State.DEAD
var holder_id: int = -1
var position := Vector3.ZERO
var velocity := Vector3.ZERO

func hold(id: int) -> void:
	state = State.HELD
	holder_id = id
	velocity = Vector3.ZERO

func is_held_by(id: int) -> bool:
	return state == State.HELD and holder_id == id
