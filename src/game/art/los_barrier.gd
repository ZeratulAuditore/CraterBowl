extends MeshInstance3D
## Pre-snap line-of-scrimmage barrier (C08d). A see-through hex wall at the LOS:
## brightens near athletes, ripples when one arrives at their neutral-zone edge,
## dissolves at the snap. Reads sim state only; the clamp itself lives in
## World.enforce_neutral_zone.

const T := preload("res://src/sim/tuning.gd")
const Mats := preload("res://src/game/art/materials.gd")
const MAX_REVEAL := 8
const MAX_RIPPLES := 4
const RIPPLE_LIFE := 0.8

var mat: ShaderMaterial
var width := 53.0
var drop_t := -1.0          # >= 0 while dissolving after the snap
var ripples: Array = []     # [x, age]
var _touching := {}         # athlete id -> at their edge last frame
var _last_phase := -1

func setup(field_width: float) -> void:
	name = "LosBarrier"
	width = field_width
	var q := QuadMesh.new()
	q.size = Vector2(width, T.BARRIER_HEIGHT)
	mesh = q
	mat = Mats.shader("res://src/game/art/los_barrier.gdshader")
	mat.set_shader_parameter("width_m", width)
	mat.set_shader_parameter("height_m", T.BARRIER_HEIGHT)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false

## Call each frame. focus_id = the local player's athlete (revealed strongest).
func update(w, delta: float, focus_id: int) -> void:
	var ph := int(w.phase)
	var fresh := ph == 0 and _last_phase != 0
	if ph == 0:
		drop_t = -1.0
		visible = true
	elif _last_phase == 0 and ph == 1:
		drop_t = 0.0
	_last_phase = ph
	if drop_t >= 0.0:
		drop_t += delta
		if drop_t >= T.BARRIER_DROP_TIME:
			drop_t = -1.0
			visible = false
	elif ph != 0:
		visible = false
	if not visible:
		return
	position = Vector3(width / 2.0, T.BARRIER_HEIGHT / 2.0, -w.los_y)
	mat.set_shader_parameter("drop", clampf(drop_t / T.BARRIER_DROP_TIME, 0.0, 1.0) if drop_t >= 0.0 else 0.0)
	if ph == 0:
		_track(w, fresh, focus_id)
	for r in ripples:
		r[1] += delta / RIPPLE_LIFE
	ripples = ripples.filter(func(r): return r[1] < 1.0)
	var rp := []
	for i in MAX_RIPPLES:
		rp.append(Vector4(ripples[i][0], ripples[i][1], 0, 0) if i < ripples.size() else Vector4(0, -1, 0, 0))
	mat.set_shader_parameter("ripple", rp)

func _track(w, fresh: bool, focus_id: int) -> void:
	var near := []
	for a in w.athletes:
		var gap: float = absf(a.position.y - w.los_y) - T.NEUTRAL_ZONE_HALF
		if gap < T.BARRIER_REVEAL_DIST:
			var s := 1.0 - maxf(gap, 0.0) / T.BARRIER_REVEAL_DIST
			s *= 1.0 if a.id == focus_id else 0.6
			near.append(Vector4(a.position.x, s, 0, 0))
		var edge: float = w.los_y + (-T.NEUTRAL_ZONE_HALF if a.team == w.offense_team else T.NEUTRAL_ZONE_HALF)
		var touch := absf(a.position.y - edge) < 0.03
		# Ripple on arrival only; athletes lined up at the edge (C) are seeded silently.
		if touch and not fresh and not _touching.get(a.id, false):
			add_ripple(a.position.x)
		_touching[a.id] = touch
	near.sort_custom(func(p, q): return p.y > q.y)
	var rv := []
	for i in MAX_REVEAL:
		rv.append(near[i] if i < near.size() else Vector4.ZERO)
	mat.set_shader_parameter("reveal", rv)

func add_ripple(x: float) -> void:
	ripples.append([x, 0.0])
	if ripples.size() > MAX_RIPPLES:
		ripples.pop_front()
