extends "res://tests/visual/harness.gd"
## #128 camera framing at 1280x720. The follow camera keeps the controlled player's ring
## above the scorebug (pre-snap on defense, live while backpedalling toward the camera, and
## the dead-ball whistle after a sack). The passer's over-the-shoulder POV keeps every
## nearby offensive teammate whole; only a far wideout may leave the frame.
## Every capture waits for the camera to stop moving first (reproducible, #124).

const RING_R := 1.1        # PlayerRing quad half-size (presentation.gd): outer bound of the glow
const BODY_HALF_W := 0.55  # athlete silhouette half-width incl. shoulder pads
const BODY_H := 2.0        # feet to helmet top
const FAR_RECEIVER := 8.0  # yards from the QB: wideouts this far out may sit outside the POV frame

var game

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.auto_next = false
	game.opening_kickoff = false
	game.configure(7)
	game.ai.defense_enabled = false

	# Pre-snap, the passer's over-the-shoulder POV (shot.sh --snap=120 frame 60 in the issue).
	_new_play(0, 30.0)
	await _settle()
	check(game.world.phase == game.World.Phase.PRESNAP and game.pov_active() and game.pov_w >= 1.0, "7v7 pre-snap: the QB is in the settled POV camera")
	var qb = game.world.get_athlete(game.controlled_id)
	var near := 0
	for a in game.world.athletes:
		if a.team != qb.team or a.id == qb.id:
			continue
		var r := _body_rect(game.views[a.id])
		var far: bool = absf(a.position.x - qb.position.x) > FAR_RECEIVER
		var inside := _view_rect().encloses(r)
		if not far:
			near += 1
			check(inside, "POV: teammate #%d (%.1f yd across, %.1f yd back) is fully in frame %s" % [a.id, a.position.x - qb.position.x, qb.position.y - a.position.y, r])
		else:
			print("VISUAL INFO POV: far receiver #%d %.1f yd across, in frame: %s" % [a.id, a.position.x - qb.position.x, inside])
	check(near >= 4, "POV: %d nearby teammates checked (line + backs)" % near)
	await capture("camera-framing-pov-presnap")

	# Pre-snap on defense: follow camera looking back at the offense (yaw PI).
	_new_play(1, 30.0)
	await _settle()
	check(game.world.phase == game.World.Phase.PRESNAP and not game.pov_active() and game.player.athlete.team != game.world.offense_team, "pre-snap on defense: follow camera")
	_check_ring("defense pre-snap")
	await capture("camera-framing-defense-presnap")

	# Live follow, worst case: the reticle pushed to max range (look point far downfield)
	# while the player backpedals toward the lagging camera. Checked every frame.
	_new_play(0, 30.0)
	game.pov_enabled = false   # same follow path as a receiver/runner/defender
	await _settle()
	_check_ring("offense pre-snap (POV off)")
	_snap()
	await _frames(20)
	check(game.world.phase == game.World.Phase.LIVE, "snapped")
	game.aim_distance = 65.0
	var c = game.world.get_athlete(game.controlled_id)
	var worst := -INF
	var bug_top: float = game.pres.overlay.bug.get_global_rect().position.y
	for i in 60:
		c.position.y -= 0.14   # ~8.4 yd/s toward the camera
		await process_frame
		worst = maxf(worst, _ring_rect().end.y)
	check(worst < bug_top, "live backpedal at max aim range: lowest ring edge %.0f px stays above the scorebug top %.0f px" % [worst, bug_top])

	# Dead ball after a sack (frame 240 in the issue): POV on, QB driven back and tackled.
	_new_play(0, 30.0)
	game.pov_enabled = true
	await _settle()
	_snap()
	for i in 120:   # the shotgun snap is in the air for a moment
		await physics_frame
		if game.world.ball.is_held_by(game.controlled_id):
			break
	c = game.world.carrier()
	check(c != null and c.id == game.controlled_id, "QB has the snap")
	var cx: float = game.world.field.width / 2.0
	c.position = Vector2(cx, 24.0)
	var lb = game.world.find_role(1, game.Athlete.Role.LB)
	lb.position = c.position + Vector2(0, 0.75)
	lb.facing = Vector2(0, -1)
	await _frames(2)
	check(game.world.tackle(lb.id), "LB sacks the QB")
	for i in 120:
		await physics_frame
		if game.world.phase == game.World.Phase.DEAD:
			break
	check(game.world.phase == game.World.Phase.DEAD, "whistle: dead ball")
	await _settle()
	check(game.pov_w <= 0.0, "dead ball uses the follow camera")
	_check_ring("dead ball (sack)")
	await capture("camera-framing-dead-ball-sack")
	finish()

func _new_play(offense: int, los: float) -> void:
	game.series.start(offense, los)
	game.series.clock.new_play()   # fresh :20 each scene, nowhere near delay of game
	game.set_controlled(game.my_id)
	game.play_picker_open = false

func _snap() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	game._unhandled_key_input(ev)

func _view_rect() -> Rect2:
	return root.get_visible_rect()

## Screen rect of an athlete's upright silhouette box (feet to helmet, shoulder width).
func _body_rect(v: Node3D) -> Rect2:
	var cam: Camera3D = game.camera
	var right: Vector3 = cam.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var r := Rect2()
	var first := true
	for h in [0.0, BODY_H]:
		for s in [-1.0, 1.0]:
			var p: Vector3 = v.global_position + Vector3(0, h, 0) + right * s * BODY_HALF_W
			if cam.is_position_behind(p):
				return Rect2(-1e6, -1e6, 1, 1)
			var sp := cam.unproject_position(p)
			r = Rect2(sp, Vector2.ZERO) if first else r.expand(sp)
			first = false
	return r

## Screen rect of the controlled player's ground ring (sampled around its outer edge).
func _ring_rect() -> Rect2:
	var cam: Camera3D = game.camera
	var ring: Node3D = game.pres.ring
	var r := Rect2(cam.unproject_position(ring.global_position), Vector2.ZERO)
	for i in 24:
		var t := TAU * i / 24.0
		r = r.expand(cam.unproject_position(ring.global_position + Vector3(cos(t), 0, sin(t)) * RING_R))
	return r

func _check_ring(what: String) -> void:
	var ov = game.pres.overlay
	var bug: Rect2 = ov.bug.get_global_rect()
	var ring := _ring_rect()
	check(_view_rect().encloses(ring), "%s: ring %s is on screen" % [what, ring])
	check(ring.end.y < bug.position.y, "%s: ring bottom %.0f px is above the scorebug top %.0f px" % [what, ring.end.y, bug.position.y])
	if ov.status_pill.visible:
		check(not ring.intersects(ov.status_pill.get_global_rect()), "%s: ring clears the status pill" % what)

## Run frames until the camera has stopped moving (position, aim and POV blend), so the
## capture doesn't depend on how many frames ran.
func _settle() -> void:
	var last: Transform3D = game.camera.global_transform
	var still := 0
	for frame in 400:
		await process_frame
		var t: Transform3D = game.camera.global_transform
		var moved: bool = t.origin.distance_to(last.origin) > 0.0001 or not t.basis.is_equal_approx(last.basis)
		last = t
		still = 0 if moved or (game.pov_w > 0.0 and game.pov_w < 1.0) else still + 1
		if still >= 3:
			print("VISUAL INFO camera settled after %d frames" % frame)
			break
	await process_frame

func _frames(n: int) -> void:
	for i in n:
		await physics_frame
