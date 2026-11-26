extends "res://tests/test_case.gd"
## #139: radial taunt wheel. Pure selection math (direction -> slice, dead zone, clamp)
## and the release rules (highlighted performs, dead zone cancels, tap repeats the last).
## The real C key / mouse path is driven in tests/game_flow.gd (frames 12730-12800).

const Radial := preload("res://src/game/radial_select.gd")
const Wheel := preload("res://src/game/taunt_wheel.gd")
const Emotes := preload("res://src/sim/emotes.gd")
const World := preload("res://src/sim/world.gd")
const Match := preload("res://src/sim/match.gd")
const Athlete := preload("res://src/sim/athlete.gd")

func test_direction_maps_to_slice_clockwise_from_up() -> void:
	var dirs := [Vector2(0, -1), Vector2(1, -1), Vector2(1, 0), Vector2(1, 1),
		Vector2(0, 1), Vector2(-1, 1), Vector2(-1, 0), Vector2(-1, -1)]
	for i in dirs.size():
		assert_eq(Radial.slice_at(dirs[i] * 50.0, 8, 10.0), i, "8 slices: direction %s" % str(dirs[i]))
		assert_true(Radial.slice_dir(i, 8).dot(dirs[i].normalized()) > 0.999, "slice %d centre points %s" % [i, str(dirs[i])])
	# Boundaries: slice 0 spans -22.5..22.5 deg; just past 22.5 deg is slice 1.
	assert_eq(Radial.slice_at(Vector2.from_angle(deg_to_rad(-90.0 + 22.0)) * 50.0, 8, 10.0), 0, "22 deg right of up")
	assert_eq(Radial.slice_at(Vector2.from_angle(deg_to_rad(-90.0 + 23.0)) * 50.0, 8, 10.0), 1, "23 deg right of up")
	assert_eq(Radial.slice_at(Vector2.from_angle(deg_to_rad(-90.0 - 23.0)) * 50.0, 8, 10.0), 7, "23 deg left of up")
	assert_eq(Radial.slice_at(Vector2(0, 50), 6, 10.0), 3, "6 slices: straight down")
	assert_eq(Radial.slice_at(Radial.slice_dir(2, 5) * 50.0, 5, 10.0), 2, "5 slices: slice 2 centre (144 deg)")
	assert_eq(Radial.slice_at(Vector2(sin(deg_to_rad(181.0)), -cos(deg_to_rad(181.0))) * 50.0, 5, 10.0), 3, "5 slices: 181 deg is past the 180 deg edge")

func test_dead_zone_and_empty_wheel() -> void:
	assert_eq(Radial.slice_at(Vector2.ZERO, 8, 10.0), -1, "centre is no slice")
	assert_eq(Radial.slice_at(Vector2(0, -10), 8, 10.0), -1, "on the dead-zone edge is still no slice")
	assert_eq(Radial.slice_at(Vector2(0, -10.5), 8, 10.0), 0, "just past it picks")
	assert_eq(Radial.slice_at(Vector2(0, -50), 0, 10.0), -1, "no taunts, no slice")

func test_drag_clamps_so_a_short_move_reverses() -> void:
	var s := Radial.drag(Vector2.ZERO, Vector2(500, 0), 90.0)
	assert_near(s.length(), 90.0, 0.001, "clamped to the radius")
	s = Radial.drag(s, Vector2(-180, 0), 90.0)
	assert_eq(Radial.slice_at(s, 8, 24.0), 6, "a 180 px move back flips right -> left")

func test_wheel_has_a_slice_per_taunt() -> void:
	var w := Wheel.new()
	w.open_wheel()
	assert_eq(w.ids.size(), Emotes.LIST.size(), "one slice per unlocked taunt")
	assert_true(w.ids.size() >= 6 and w.ids.size() <= 8, "6-8 slices fit the wheel")
	assert_eq(w.highlighted(), "", "opens with nothing highlighted")
	w.free()

func test_release_performs_highlighted() -> void:
	var w := Wheel.new()
	w.open_wheel()
	w.drag(Vector2(80, 0))
	assert_eq(w.highlighted(), Emotes.id_at(2), "drag right highlights slice 2")
	w.held_t = 1.0
	assert_eq(w.release(), Emotes.id_at(2), "release performs it")
	assert_true(not w.open and w.last_id == Emotes.id_at(2), "closed, remembered as last")
	w.free()

func test_release_in_dead_zone_cancels() -> void:
	var w := Wheel.new()
	w.open_wheel()
	w.drag(Vector2(0, -60))
	w.drag(Vector2(0, 60))
	assert_eq(w.release(), "", "dragged out and back to the centre: cancel")
	w.open_wheel()
	w.held_t = Wheel.TAP_TIME + 0.1
	assert_eq(w.release(), "", "held without dragging: cancel")
	assert_true(not w.open, "closed")
	w.free()

func test_tap_repeats_last_taunt() -> void:
	var w := Wheel.new()
	w.open_wheel()
	assert_eq(w.release(), Emotes.id_at(0), "first tap: the first taunt")
	w.open_wheel()
	w.drag(Vector2(0, 80))
	w.release()
	w.open_wheel()
	w.drag(Vector2(5, 5))   # a twitch inside the dead zone is still a tap
	assert_eq(w.release(), Emotes.id_at(4), "tap repeats the last taunt picked")
	w.free()

## #240: athletes stay stance-locked until the snap (#142), and the taunt cooldown
## must still run so a set player can taunt more than once per pre-snap.
func test_locked_athlete_taunt_recharges_presnap() -> void:
	var w := World.new()
	var cx := w.field.width / 2.0
	for t in 2:
		w.add_two_way(t, Athlete.Role.QB, cx, Athlete.Role.LB, cx)
	var m := Match.new(w)
	m.start(0, 25.0)
	var qb := w.find_role(0, Athlete.Role.QB)
	assert_true(w.phase == World.Phase.PRESNAP and qb.set_lock, "QB lines up set")
	assert_true(w.emote(qb.id, Emotes.id_at(0)), "first taunt")
	assert_true(not w.emote(qb.id, Emotes.id_at(1)), "rate-limited right after")
	for i in int(ceil(Emotes.COOLDOWN * 60.0)) + 2:
		w.step({}, 1.0 / 60.0)
	assert_true(w.phase == World.Phase.PRESNAP and qb.set_lock, "still set, not snapped")
	assert_true(w.emote(qb.id, Emotes.id_at(1)), "taunts again after the cooldown while still set")
