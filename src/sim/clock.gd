extends RefCounted
## Game + play clock. Game clock runs only during live play. Pure.

const HALF_LENGTH := 300.0
const HALVES := 2
const PLAY_CLOCK := 20.0

var half := 1
var remaining := HALF_LENGTH
var play_clock := PLAY_CLOCK
var final := false

func reset() -> void:
	half = 1
	remaining = HALF_LENGTH
	play_clock = PLAY_CLOCK
	final = false

func expired() -> bool:
	return remaining <= 0.0

## Advance. live/presnap describe the current world phase.
## Returns true when the play clock just ran out (caller snaps).
func tick(dt: float, live: bool, presnap: bool) -> bool:
	if final:
		return false
	if live:
		remaining = maxf(0.0, remaining - dt)
	elif presnap:
		play_clock = maxf(0.0, play_clock - dt)
		if play_clock <= 0.0:
			return true
	return false

func new_play() -> void:
	play_clock = PLAY_CLOCK

func start_next_half() -> void:
	half += 1
	remaining = HALF_LENGTH
	play_clock = PLAY_CLOCK

func label() -> String:
	if final:
		return "FINAL"
	var s := int(ceil(remaining))
	return "H%d %d:%02d" % [half, s / 60, s % 60]
