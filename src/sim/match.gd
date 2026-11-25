extends RefCounted
## Match flow layer: World (one play) + Downs (series). Score/clock come in A08/A09.

const World := preload("res://src/sim/world.gd")
const Downs := preload("res://src/sim/downs.gd")

signal match_event(name: String, data: Dictionary)

var world: World
var downs := Downs.new()
var last_result := {}
var last_outcome := {}

func _init(w: World) -> void:
	world = w
	world.event.connect(_on_world_event)

func start(offense: int = 0, los: float = 25.0) -> void:
	downs.reset(offense, los)
	world.set_offense(offense)
	world.setup_formation(los)

func _on_world_event(n: String, d: Dictionary) -> void:
	match n:
		"tackle", "out_of_bounds":
			last_result = {"type": n, "spot": d["spot"].y}
		"incomplete":
			last_result = {"type": "incomplete"}

## Apply the last play's result and line up for the next snap.
func next_play() -> Dictionary:
	if last_result.is_empty():
		last_result = {"type": "incomplete"}
	last_outcome = downs.apply(last_result)
	last_result = {}
	if downs.offense_team != world.offense_team:
		world.set_offense(downs.offense_team)
	world.setup_formation(downs.los)
	match_event.emit(last_outcome["outcome"], last_outcome)
	return last_outcome
