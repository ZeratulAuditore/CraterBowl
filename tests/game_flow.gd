extends SceneTree
## Scripted end-to-end flow through the real main scene (presentation glue).
## Each step: [physics frame @60Hz, callable]. Exits 1 on failed check.

var main
var frame := 0
var ok := true
var steps: Array = []
var caught_by := -1
var tackled := false
var spot := 0.0
var series_events := 0
var wr_id := -1

func check(cond: bool, msg: String) -> void:
	print(("  FLOW OK   " if cond else "  FLOW FAIL ") + msg)
	if not cond:
		ok = false

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.auto_next = false
	# scripted steps drive play changes; auto-advance checked at the end
	main.world.event.connect(func(n, d): if n == "catch": caught_by = d["by"])
	main.world.event.connect(func(n, d): if n == "tackle" and caught_by >= 0: tackled = true)
	steps = [
		[2, func(): main.series.match_event.connect(func(_n, _d): series_events += 1)],  # series exists after _ready
		[5, func(): check(main.world.phase == main.World.Phase.PRESNAP, "starts presnap")],
		[6, func(): check(main.world.snap(), "snap")],
		[40, func(): check(main.world.ball.is_held_by(main.controlled_id), "QB has ball")],
		[41, func(): main.aim_point = Vector2(40, 45); main._set_charging(true)],
		[80, func(): check(main.charge > 0.3, "charge builds (%.2f)" % main.charge); check(main.arc_dots[0].visible, "arc preview shown")],
		[81, func(): main._set_charging(false)],
		[82, func(): check(main.world.forward_pass_thrown, "pass thrown")],
		[400, func(): check(main.world.phase == main.World.Phase.DEAD, "incomplete ends play")],
		# A04: reset, snap, lead a pass to a WR running his go route -> catch + control switch
		[401, func(): main.next_play(); check(main.series.downs.down == 2, "incomplete -> 2nd down"); check(main.controlled_id == main.my_id, "control back to my athlete")],
		[402, func(): main.world.snap()],
		[480, func(): _lead_to_wr()],
		[481, func(): main._set_charging(true)],
		[530, func(): main._set_charging(false)],
		[531, func(): check(main.world.forward_pass_thrown, "lead pass thrown")],
		[800, func(): check(caught_by >= 0, "WR caught it"); check(main.controlled_id == caught_by, "control switched to receiver")],
		# A05: idle receiver gets run down by AI pursuit and tackled
		[1300, func(): check(tackled, "AI defender tackled the carrier"); check(main.world.phase == main.World.Phase.DEAD, "whistle: play dead"); check(main.last_whistle == "TACKLE", "HUD whistle reason")],
		# A07: next play at the tackle spot with correct down
		[1301, func(): spot = main.world.dead_ball_spot.y; main.next_play()],
		[1302, func(): check(absf(main.world.los_y - clampf(spot, 1, 99)) < 0.01, "LOS moved to tackle spot"); check(main.series.downs.down == 1 if spot >= 35.0 else main.series.downs.down == 3, "down advanced correctly (spot %.1f, %s)" % [spot, main.series.downs.label()]); check(main.hud.text.find(" & ") >= 0, "HUD shows down & distance")],
		[1303, func(): main.world.snap(); main.auto_next = true; series_events = 0],
		[2400, func(): check(series_events >= 1, "auto next play fired after whistle (%d)" % series_events)],
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
	if steps.is_empty():  # _initialize failed: never hang
		print("GAME FLOW FAIL (setup error)")
		quit(1)
		return true
	frame += 1
	for s in steps:
		if s[0] == frame:
			s[1].call()
	if frame > steps[-1][0]:
		print("GAME FLOW " + ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
	return false
