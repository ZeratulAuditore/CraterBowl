extends SceneTree
## Scripted end-to-end flow through the real main scene (presentation glue).
## Each step: [physics frame @60Hz, callable]. Exits 1 on failed check.

var main
var frame := 0
var ok := true
var steps: Array = []

func check(cond: bool, msg: String) -> void:
	print(("  FLOW OK   " if cond else "  FLOW FAIL ") + msg)
	if not cond:
		ok = false

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	steps = [
		[5, func(): check(main.world.phase == main.World.Phase.PRESNAP, "starts presnap")],
		[6, func(): check(main.world.snap(), "snap")],
		[40, func(): check(main.world.ball.is_held_by(main.controlled_id), "QB has ball")],
		[41, func(): main.aim_point = Vector2(40, 45); main._set_charging(true)],
		[80, func(): check(main.charge > 0.3, "charge builds (%.2f)" % main.charge); check(main.arc_dots[0].visible, "arc preview shown")],
		[81, func(): main._set_charging(false)],
		[82, func(): check(main.world.forward_pass_thrown, "pass thrown")],
		[400, func(): check(main.world.phase == main.World.Phase.DEAD, "incomplete ends play")],
	]

func _physics_process(_dt: float) -> bool:
	frame += 1
	for s in steps:
		if s[0] == frame:
			s[1].call()
	if frame > steps[-1][0]:
		print("GAME FLOW " + ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false
