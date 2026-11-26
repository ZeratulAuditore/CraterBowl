extends RefCounted
## Taunt emotes: cosmetic only (no gameplay effect). Hold C for the radial taunt wheel,
## drag toward one and release (src/game/taunt_wheel.gd, #139). Server-validated +
## rate-limited, broadcast as world event "emote" {by, e}. Pure data.

## [id, menu name, animation clip, speech bubble]
const LIST := [
	["bring_it", "Bring It", "Punch_Cross", "BRING IT"],
	["nope", "Nope", "u2/Idle_No", "NOPE"],
	["unbothered", "Unbothered", "u2/Idle_FoldArms", "YAWN"],
	["shimmy", "Shimmy", "Dance", "TOO SMOOTH"],
	["phone", "Hello?", "u2/Idle_TalkingPhone", "HELLO? TOO SLOW"],
	["holler", "Holler", "u2/Idle_Rail_Call", "OVER HERE!"],
	["nod", "Nod", "u2/Yes", "YEP"],
	["zap", "Zap", "Spell_Simple_Shoot", "ZAP"],
]
const DURATION := 1.8   # seconds the clip + bubble play
const COOLDOWN := 1.0   # min seconds between emotes per athlete

static func has(id: String) -> bool:
	return index_of(id) >= 0

static func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i][0] == id:
			return i
	return -1

static func id_at(i: int) -> String:
	return LIST[posmod(i, LIST.size())][0]

static func clip(id: String) -> String:
	var i := index_of(id)
	return LIST[i][2] if i >= 0 else ""

static func bubble(id: String) -> String:
	var i := index_of(id)
	return LIST[i][3] if i >= 0 else ""

static func display_name(id: String) -> String:
	var i := index_of(id)
	return LIST[i][1] if i >= 0 else id
