extends RefCounted
## Radial menu math (#139): which slice a drag points at. Pure + static so it is
## unit-testable without a scene. Screen space: +x right, +y down. Slice 0 is centred
## straight up and the rest follow clockwise, each TAU / count wide.

## Slice the selector `v` points at, or -1 while it sits inside the dead zone
## (length <= dead_zone) or there are no slices.
static func slice_at(v: Vector2, count: int, dead_zone: float) -> int:
	if count <= 0 or v.length() <= dead_zone:
		return -1
	var step := TAU / count
	var a := atan2(v.x, -v.y)   # 0 = up, grows clockwise, in (-PI, PI]
	return posmod(int(floor((a + step * 0.5) / step)), count)

## Unit vector through the middle of slice i.
static func slice_dir(i: int, count: int) -> Vector2:
	var a := TAU * i / maxi(count, 1)
	return Vector2(sin(a), -cos(a))

## Move the selector by a relative mouse/stick delta, clamped to `radius` so a long drag
## can always be reversed with a short one.
static func drag(selector: Vector2, rel: Vector2, radius: float) -> Vector2:
	return (selector + rel).limit_length(radius)
