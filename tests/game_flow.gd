extends SceneTree
## Scripted end-to-end flow through the real main scene (presentation glue).
## Each step: [physics frame @60Hz, callable]. Exits 1 on failed check.

var main
var frame := 0
var ok := true
var steps: Array = []
var caught_by := -1
var wr_id := -1

func check(cond: bool, msg: String) -> void:
	print(("  FLOW OK   " if cond else "  FLOW FAIL ") + msg)
	if not cond:
		ok = false

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.world.event.connect(func(n, d): if n == "catch": caught_by = d["by"])
	steps = [
		[5, func(): check(main.world.phase == main.World.Phase.PRESNAP, "starts presnap")],
		[6, func(): check(main.world.snap(), "snap")],
		[40, func(): check(main.world.ball.is_held_by(main.controlled_id), "QB has ball")],
		[41, func(): main.aim_point = Vector2(40, 45); main._set_charging(true)],
		[80, func(): check(main.charge > 0.3, "charge builds (%.2f)" % main.charge); check(main.arc_dots[0].visible, "arc preview shown")],
		[81, func(): main._set_charging(false)],
		[82, func(): check(main.world.forward_pass_thrown, "pass thrown")],
		[400, func(): check(main.world.phase == main.World.Phase.DEAD, "incomplete ends play")],
		# A04: reset, snap, lead a pass to a WR running his go route -> catch + control switch
		[401, func(): main.world.setup_formation(25.0); main.set_controlled(main.world.find_role(0, main.Athlete.Role.QB).id)],
		[402, func(): main.world.snap()],
		[480, func(): _lead_to_wr()],
		[481, func(): main._set_charging(true)],
		[530, func(): main._set_charging(false)],
		[531, func(): check(main.world.forward_pass_thrown, "lead pass thrown")],
		[800, func(): check(caught_by >= 0, "WR caught it"); check(main.controlled_id == caught_by, "control switched to receiver")],
	]

func _lead_to_wr() -> void:
	var qb = main.world.find_role(0, main.Athlete.Role.QB)
	var wr = main.world.find_role(0, main.Athlete.Role.WR)
	var from: Vector3 = Vector3(qb.position.x, qb.position.y, main.T.RELEASE_HEIGHT)
	# charge ~50 frames ≈ 0.83s of 0.9s -> power ~0.92; lead with that power
	var p: float = 50.0 / 60.0 / main.T.THROW_CHARGE_TIME
	var t_extra := 50.0 / 60.0  # WR keeps running while QB charges
	main.aim_point = main.Passing.lead_target(from, wr.position + wr.velocity * t_extra, wr.velocity, p)

func _physics_process(_dt: float) -> bool:
	frame += 1
	for s in steps:
		if s[0] == frame:
			s[1].call()
	if frame > steps[-1][0]:
		print("GAME FLOW " + ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false
