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

# --- B04a: play summaries, highlights, clip controls ---
func _play(w: World, r: Replay, frames: int) -> void:
	for i in frames:
		w.step({}, DT)
		r.capture(w)

func test_play_summary_yards_and_context() -> void:
	var s := _rec()
	var w: World = s[0]
	var r: Replay = s[2]
	r.context = "Q1 2:00, 1st & 10 at OWN 25"
	_play(w, r, 4)
	var los := w.los_y
	w.snap()
	_play(w, r, 20)
	w.event.emit("tackle", {"carrier": 99, "team": w.offense_team, "spot": Vector2(20, los + 6.4)})
	var p: Dictionary = r.plays[0]
	assert_near(p["yards"], 6.4, 0.01)
	assert_eq(p["summary"], "run for 6 yd")
	assert_true(not (p["highlight"]), "short run is not a highlight")
	assert_eq(p["label"], "Play 1 (Q1 2:00, 1st & 10 at OWN 25): run for 6 yd")

func test_highlight_tags() -> void:
	var s := _rec()
	var w: World = s[0]
	var r: Replay = s[2]
	var los := w.los_y
	# 1: long pass gain
	w.snap(); _play(w, r, 10)
	w.event.emit("throw", {"by": 1}); _play(w, r, 10)
	w.event.emit("tackle", {"carrier": 5, "team": w.offense_team, "spot": Vector2(20, los + 31.0)})
	# 2: touchdown
	w.event.emit("snap", {"qb": 1}); _play(w, r, 10)
	w.event.emit("touchdown", {"carrier": 5, "team": w.offense_team, "spot": Vector2(20, w.field.goal_line_b() + 3.0)})
	# 3: interception
	w.event.emit("snap", {"qb": 1}); _play(w, r, 10)
	w.event.emit("throw", {"by": 1}); w.event.emit("interception", {"by": 9, "team": 1 - w.offense_team})
	_play(w, r, 10)
	w.event.emit("tackle", {"carrier": 9, "team": 1 - w.offense_team, "spot": Vector2(20, los + 10.0)})
	# 4: sack (QB tackled behind the line, no throw)
	w.event.emit("snap", {"qb": 1}); _play(w, r, 10)
	var qb: int = 1
	w.event.emit("tackle", {"carrier": qb, "team": w.offense_team, "spot": Vector2(20, los - 7.0)})
	# 5: incomplete
	w.event.emit("snap", {"qb": 1}); _play(w, r, 10)
	w.event.emit("incomplete", {})
	assert_eq(r.plays.size(), 5)
	assert_eq(r.plays[0]["summary"], "pass for 31 yd")
	assert_true(r.plays[0]["highlight"], "20+ yd play is a highlight")
	assert_true(r.plays[1]["summary"].begins_with("TOUCHDOWN"), r.plays[1]["summary"])
	assert_near(r.plays[1]["yards"], w.field.goal_line_b() - los, 0.01, "TD yards stop at the goal line")
	assert_true(r.plays[2]["summary"].begins_with("INTERCEPTION"), r.plays[2]["summary"])
	assert_eq(r.plays[3]["summary"], "SACK: loss of 7")
	assert_true(not (r.plays[4]["highlight"]))
	assert_true(r.plays[4]["label"].ends_with("incomplete"))
	assert_eq(r.highlights(), [0, 1, 2, 3])
	r.time = float(r.plays[1]["start"])
	assert_eq(r.next_highlight(), 2, "next highlight after the current play")
	r.time = float(r.plays[4]["start"])
	assert_eq(r.next_highlight(), 0, "wraps")

func _synthetic() -> Replay:
	var r := Replay.new()
	for i in 200:
		r.frames.append(PackedFloat32Array([1, 0, 0, 0, float(i), 0.0, 0.0]))
	r.plays = [{"start": 0, "end": 90, "label": "a", "highlight": true},
		{"start": 100, "end": 140, "label": "b"}, {"start": 150, "end": 199, "label": "c", "highlight": true}]
	return r

func test_highlight_clip_slowmo_and_reel() -> void:
	var r := _synthetic()
	assert_true(r.clip_play(0, 1.0, true))
	assert_near(r.slowmo_from, 30.0, 0.001, "last 2 s are slow motion")
	assert_near(r.effective_speed(), 1.0, 0.001)
	r.time = 40.0
	assert_near(r.effective_speed(), Replay.SLOWMO_SPEED, 0.001, "slow-mo tail")
	assert_true(r.start_reel(r.highlights()))
	assert_near(r.time, 0.0)
	assert_eq(r.reel, [2])
	r.advance(100.0)
	assert_true(r.ended())
	assert_true(r.next_in_reel(), "reel moves to the next highlight")
	assert_near(r.time, 150.0)
	r.advance(100.0)
	assert_true(not (r.next_in_reel()), "reel done")
	assert_true(not (r.clip_play(7)), "bad index refused")

func test_frame_step_progress_and_old_files() -> void:
	var r := _synthetic()
	r.clip_play(1, 0.5)
	r.step_frames(-5)
	assert_near(r.time, 100.0, 0.001, "frame-step clamps to the clip start")
	r.step_frames(3)
	assert_near(r.time, 103.0, 0.001)
	r.step_frames(1000)
	assert_near(r.time, 140.0, 0.001, "and to the clip end")
	assert_near(r.progress(), 1.0, 0.001)
	r.time = 120.0
	assert_near(r.progress(), 0.5, 0.001)
	assert_true(r.clip_play(2, -1.0))
	assert_near(r.speed, 0.5, 0.001, "spd <= 0 keeps the current speed")
	# Pre-B04 files: plays have no highlight key.
	r.plays = [{"start": 0, "end": 10, "label": "Play 1 - tackle"}]
	assert_eq(r.highlights(), [])
	assert_eq(r.next_highlight(), -1)
