extends RefCounted
## Field geometry on the 2D sim plane (yards).
## x: 0..width across, y: 0..length between goal lines; end zones beyond.

const T := preload("res://src/sim/tuning.gd")

enum Zone { FIELD, ENDZONE_A, ENDZONE_B, OUT_OF_BOUNDS }

var length: float = T.FIELD_LENGTH
var width: float = T.FIELD_WIDTH
var endzone_depth: float = T.ENDZONE_DEPTH

func goal_line_a() -> float:
	return 0.0

func goal_line_b() -> float:
	return length

func in_bounds(p: Vector2) -> bool:
	return p.x >= 0.0 and p.x <= width and p.y >= -endzone_depth and p.y <= length + endzone_depth

func zone_of(p: Vector2) -> Zone:
	if not in_bounds(p):
		return Zone.OUT_OF_BOUNDS
	if p.y < 0.0:
		return Zone.ENDZONE_A
	if p.y > length:
		return Zone.ENDZONE_B
	return Zone.FIELD

## Playable rectangle players are clamped to (includes sideline margin).
func clamp_playable(p: Vector2) -> Vector2:
	var m := T.OOB_MARGIN
	return Vector2(
		clampf(p.x, -m, width + m),
		clampf(p.y, -endzone_depth - m, length + endzone_depth + m))
