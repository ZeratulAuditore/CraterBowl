extends SceneTree
## Host the normal net smoke scenario, then give the joiner's team one possession
## so the client can exercise a handoff as the quarterback.

var main
var joined_host_team := false
var prepared_handoff := false

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _physics_process(_dt: float) -> bool:
	if prepared_handoff or not main.is_server() or main.in_lobby():
		return false
	for slot in main.roster.slots:
		if slot.owner <= main.LOCAL_PLAYER:
			continue
		if slot.team == 0:
			joined_host_team = true
		elif joined_host_team and slot.off_role == main.Athlete.Role.QB:
			main.series.start(1)
			main.ai.defense_enabled = false
			prepared_handoff = true
	return false
