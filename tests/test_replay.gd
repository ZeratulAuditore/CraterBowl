extends "res://tests/test_case.gd"

const World := preload("res://src/sim/world.gd")
const Match := preload("res://src/sim/match.gd")
const Roster := preload("res://src/sim/roster.gd")
const Replay := preload("res://src/sim/replay.gd")
const AI := preload("res://src/sim/ai.gd")
const DT := 1.0 / 60.0

func _rec() -> Array:
	var w := World.new()
	Roster.new().build(w, 7)
	var m := Match.new(w)
	m.start(0, 25.0)
	var r := Replay.new()
	r.attach(w)
	return [w, m, r]

func test_capture_rate_and_contents() -> void:
	var s := _rec()
	var w: World = s[0]
	var r: Replay = s[2]
	for i in 60:
		w.step({}, DT)
		r.capture(w)
	assert_eq(r.frames.size(), 30, "30 Hz from 60 Hz")
	var smp := r.sample()
	assert_true((smp["pos"][3] as Vector2).distance_to(w.athletes[3].position) < 0.01, "first frame matches")
	assert_eq(r.athlete_count(), 14)

func test_plays_bracketed() -> void:
	var s := _rec()
	var w: World = s[0]
	var r: Replay = s[2]
	for i in 10: w.step({}, DT); r.capture(w)
	w.snap()
	for i in 40: w.step({}, DT); r.capture(w)
	w.event.emit("incomplete", {})
	for i in 10: w.step({}, DT); r.capture(w)
	assert_eq(r.plays.size(), 1)
	var p: Dictionary = r.plays[0]
	assert_eq(p["start"], 5)
	assert_eq(p["end"], 25)
	assert_true(p["label"].ends_with("incomplete"))
	assert_eq(r.last_play(), p)

func test_player_interpolation_seek_speed() -> void:
	var r := Replay.new()
	for i in 10:
		r.frames.append(PackedFloat32Array([1, 0, 0, 0, float(i) * 2.0, 0.0, 0.0]))
	r.plays = [{"start": 0, "end": 4, "label": "a"}, {"start": 5, "end": 9, "label": "b"}]
	r.time = 2.5
	assert_near((r.sample()["pos"][0] as Vector2).x, 5.0, 0.001, "halfway between frames 2 and 3")
	r.seek_play(1)
	assert_near(r.time, 5.0)
	assert_eq(r.current_play(), 1)
	r.play_range(0, 4, 0.5)
	r.advance(2.0 / Replay.FPS)   # 2 frames of wall time at 0.5x = 1 frame
	assert_near(r.time, 1.0, 0.001, "speed scales")
	r.advance(10.0)
	assert_near(r.time, 4.0, 0.001, "clamped at clip end")
	assert_true(r.ended())

func test_save_load_and_size() -> void:
	var s := _rec()
	var w: World = s[0]
	var m: Match = s[1]
	var r: Replay = s[2]
	var ai := AI.new()
	var dead_t := 0.0
	for i in int(120.0 / DT):
		m.tick(DT)
		ai.presnap_tick(w, [], DT, m.downs.down, m.downs.distance())
		w.step(ai.think(w, []), DT)
		r.capture(w)
		if w.phase == World.Phase.DEAD:
			dead_t += DT
			if dead_t > 0.5:
				m.next_play()
				dead_t = 0.0
	r.meta = {"size": 7}
	var path := "user://test_replay.replay"
	assert_true(r.save(path))
	var bytes := FileAccess.get_file_as_bytes(path).size()
	assert_true(bytes < 1_000_000, "2-min match < 1 MB (%d bytes)" % bytes)
	var r2 := Replay.new()
	assert_true(r2.load_file(path))
	assert_eq(r2.frames.size(), r.frames.size())
	assert_eq(r2.plays.size(), r.plays.size())
	assert_true(r2.plays.size() >= 5, "plays recorded (%d)" % r2.plays.size())
	assert_eq(r2.frames[100], r.frames[100])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("    replay: %d frames, %d plays, %d bytes" % [r.frames.size(), r.plays.size(), bytes])
