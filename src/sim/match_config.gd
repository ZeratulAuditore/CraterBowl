extends RefCounted
## Match size presets. Pure.

const SIZES := {
	3: {"slots": 3, "length": 60.0, "width": 30.0, "endzone": 8.0},
	5: {"slots": 5, "length": 80.0, "width": 40.0, "endzone": 10.0},
	7: {"slots": 7, "length": 100.0, "width": 53.33, "endzone": 10.0},
}

static func normalize(size) -> int:
	return int(size) if SIZES.has(int(size)) else 7

static func get_config(size) -> Dictionary:
	return SIZES[normalize(size)]

static func apply_field(field, size) -> void:
	var c := get_config(size)
	field.length = c["length"]
	field.width = c["width"]
	field.endzone_depth = c["endzone"]
