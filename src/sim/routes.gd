extends RefCounted
## Route library + playbook. Offsets are yards from the receiver's alignment:
## +x = toward the field center (mirrored per side), +y = downfield. Pure.

const ROUTES := {
	"GO": [Vector2(0, 25)],
	"SLANT": [Vector2(0, 3), Vector2(8, 10), Vector2(16, 17)],
	"OUT": [Vector2(0, 8), Vector2(-10, 8)],
	"IN": [Vector2(0, 10), Vector2(14, 10)],
	"CURL": [Vector2(0, 10), Vector2(1, 8)],
	"POST": [Vector2(0, 10), Vector2(10, 22)],
	"CORNER": [Vector2(0, 10), Vector2(-10, 20)],
	"FLAT": [Vector2(-3, 1), Vector2(-10, 3)],
	"WHEEL": [Vector2(-6, 1), Vector2(-10, 6), Vector2(-10, 22)],
}
const ROUTE_NAMES := ["GO", "SLANT", "OUT", "IN", "CURL", "POST", "CORNER", "FLAT", "WHEEL"]

## Plays: routes for [left WR, right WR, RB].
const PLAYBOOK := {
	"Verticals": ["GO", "GO", "WHEEL"],
	"Slants": ["SLANT", "SLANT", "FLAT"],
	"Mesh": ["IN", "IN", "CURL"],
	"Curls": ["CURL", "CURL", "FLAT"],
	"Flood": ["CORNER", "OUT", "FLAT"],
	"Deep Shot": ["POST", "GO", "CURL"],
}
const PLAY_NAMES := ["Verticals", "Slants", "Mesh", "Curls", "Flood", "Deep Shot"]

## Waypoints from the middle of the line of scrimmage.
const RUN_PLAYS := {
	"Inside Zone": [Vector2(2.5, 1), Vector2(3.5, 7), Vector2(3.5, 16)],
	"Outside Sweep": [Vector2(8, -2), Vector2(13, 3), Vector2(14, 9), Vector2(14, 16)],
}
const RUN_NAMES := ["Inside Zone", "Outside Sweep"]

static func run_path(name: String, los: float, width: float, flipped: bool) -> Array:
	var waypoints := []
	var side := -1.0 if flipped else 1.0
	for offset in RUN_PLAYS[name]:
		waypoints.append(Vector2(clampf(width * 0.5 + offset.x * side, 1.0, width - 1.0), los + offset.y))
	return waypoints

static func route_index(name: String) -> int:
	return ROUTE_NAMES.find(name)

## Absolute waypoints for a receiver lined up at `start` on a field of `width`.
static func path_for(route: String, start: Vector2, width: float) -> Array:
	var inside := 1.0 if start.x < width / 2.0 else -1.0
	var out := []
	for o in ROUTES.get(route, ROUTES["GO"]):
		out.append(Vector2(clampf(start.x + o.x * inside, 0.5, width - 0.5), start.y + o.y))
	return out
