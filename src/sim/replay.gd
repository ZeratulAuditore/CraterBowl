extends RefCounted
## Match recording + playback. Pure (file I/O via save/load only).

const FRAME_EVERY := 2           # physics ticks per frame (60 Hz -> 30 Hz)
const FPS := 30.0
const HEADER := 4                # phase, ball x, y, z
const PER_ATHLETE := 3           # x, y, flags
const END_EVENTS := ["tackle", "out_of_bounds", "touchdown", "incomplete", "explode"]

var frames: Array = []           # Array[PackedFloat32Array]
var plays: Array = []            # [{start, end, label}]
var meta := {}
var _tick := 0
var _open := -1                  # index into plays of the play in progress

# --- recording ---
func attach(world) -> void:
	world.event.connect(_on_event)

func _on_event(n: String, _d: Dictionary) -> void:
	if n == "snap":
		plays.append({"start": frames.size(), "end": frames.size(), "label": "Play %d" % (plays.size() + 1)})
		_open = plays.size() - 1
	elif END_EVENTS.has(n) and _open >= 0:
		plays[_open]["end"] = frames.size()
		plays[_open]["label"] += " - " + n.replace("_", " ")
		_open = -1

func capture(world) -> void:
	_tick += 1
	if _tick % FRAME_EVERY != 0:
		return
	var f := PackedFloat32Array([world.phase, world.ball.position.x, world.ball.position.y, world.ball.position.z])
	for a in world.athletes:
		f.append_array([a.position.x, a.position.y, (1.0 if a.is_diving() else 0.0) + (2.0 if a.is_grounded() else 0.0)])
	frames.append(f)
	if _open >= 0:
		plays[_open]["end"] = frames.size()

func last_play() -> Dictionary:
	for i in range(plays.size() - 1, -1, -1):
		if plays[i]["end"] > plays[i]["start"]:
			return plays[i]
	return {}

# --- playback ---
var time := 0.0                  # in frames (fractional)
var speed := 1.0
var stop_at := -1.0              # clip end (frames) or -1 = end of match
var paused := false

func play_range(start: int, end: int, spd: float = 1.0) -> void:
	time = float(start)
	stop_at = float(end)
	speed = spd
	paused = false

func seek_play(i: int) -> void:
	if i >= 0 and i < plays.size():
		time = float(plays[i]["start"])
		stop_at = -1.0

func current_play() -> int:
	for i in range(plays.size() - 1, -1, -1):
		if time >= plays[i]["start"]:
			return i
	return 0

func advance(dt: float) -> void:
	if paused or frames.is_empty():
		return
	time = minf(time + dt * FPS * speed, _limit())

func _limit() -> float:
	var last := float(frames.size() - 1)
	return minf(stop_at, last) if stop_at >= 0.0 else last

func ended() -> bool:
	return frames.is_empty() or time >= _limit()

func athlete_count() -> int:
	return 0 if frames.is_empty() else (frames[0].size() - HEADER) / PER_ATHLETE

## {"ball": Vector3, "pos": Array[Vector2], "flags": Array[int], "phase": int} at the current time.
func sample() -> Dictionary:
	if frames.is_empty():
		return {}
	var i := clampi(int(floor(time)), 0, frames.size() - 1)
	var j := mini(i + 1, frames.size() - 1)
	var k := clampf(time - float(i), 0.0, 1.0)
	var a: PackedFloat32Array = frames[i]
	var b: PackedFloat32Array = frames[j]
	var pos := []
	var flags := []
	for n in athlete_count():
		var o := HEADER + n * PER_ATHLETE
		pos.append(Vector2(lerpf(a[o], b[o], k), lerpf(a[o + 1], b[o + 1], k)))
		flags.append(int(a[o + 2]))
	return {"ball": Vector3(lerpf(a[1], b[1], k), lerpf(a[2], b[2], k), lerpf(a[3], b[3], k)), "pos": pos, "flags": flags, "phase": int(a[0])}

# --- persistence ---
func save(path: String) -> bool:
	var f := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return false
	f.store_var({"version": 1, "meta": meta, "plays": plays, "frames": frames})
	return true

func load_file(path: String) -> bool:
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return false
	var d = f.get_var(false)   # never decode objects
	if not (d is Dictionary) or not (d.get("frames") is Array):
		return false
	frames = d["frames"]
	plays = d.get("plays", [])
	meta = d.get("meta", {})
	time = 0.0
	stop_at = -1.0
	return true
