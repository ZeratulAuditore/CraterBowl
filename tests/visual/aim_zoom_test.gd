extends "res://tests/visual/harness.gd"
## #109 aim-zoom: the QB's POV camera at rest (65°) and at a full throw charge (45°).
## 3v3 pre-snap: the QB already holds the ball and nobody moves, so only the FOV differs.
## Each capture waits for the FOV easing to settle (reproducible, #124).

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = preload("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.auto_next = false
	game.opening_kickoff = false
	game.configure(3)
	game.ai.defense_enabled = false
	game.series.start(0)
	game.set_controlled(game.my_id)
	game.play_picker_open = false
	var rest_fov: float = await _settle(game, game.CAMERA_FOV)
	check(game.world.phase == game.World.Phase.PRESNAP and game.world.ball.is_held_by(game.controlled_id), "3v3 pre-snap: the QB holds the ball")
	check(game.pov_active() and game.pov_w >= 1.0, "the passer is in the settled POV camera")
	check(absf(rest_fov - game.CAMERA_FOV) < 0.01, "resting FOV is %.0f (%.2f)" % [game.CAMERA_FOV, rest_fov])
	await capture("aim-zoom-rest")

	game._set_charging(true)   # the real throw-hold path (J / left click)
	check(game.charging, "holding the throw charges")
	game.charge = 1.0
	var zoom_fov: float = await _settle(game, game.AIM_ZOOM_FOV)
	check(game.charging and absf(zoom_fov - game.AIM_ZOOM_FOV) < 0.01, "full charge narrows the FOV to %.0f (%.2f)" % [game.AIM_ZOOM_FOV, zoom_fov])
	await capture("aim-zoom-full-charge")
	finish()

## Run frames until the POV blend is done, the camera has stopped and the eased FOV
## reaches its target (returns where it got to), then pin the FOV so the PNG is exact.
func _settle(game, target: float) -> float:
	var last: Vector3 = game.camera.global_position
	for frame in 240:
		await process_frame
		var still: bool = game.camera.global_position.distance_to(last) < 0.0001
		last = game.camera.global_position
		if game.pov_w >= 1.0 and still and absf(game.camera.fov - target) < 0.01:
			break
	var reached: float = game.camera.fov
	game.camera.fov = target
	for frame in 2:
		await process_frame
	return reached
