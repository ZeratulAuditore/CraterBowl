extends RefCounted
## Game and play clocks, warning and team timeouts. Pure.

const HALF_LENGTH := 300.0
const HALVES := 2
const PLAY_CLOCK := 20.0
const WARNING_TIME := 60.0
const TIMEOUTS_PER_HALF := 3
const SMALL_MATCH_TIMEOUTS := 2

var half := 1
var half_length := HALF_LENGTH
var remaining := HALF_LENGTH
var play_clock := PLAY_CLOCK
var final := false
var running_between_plays := false
var timeout_limit := TIMEOUTS_PER_HALF
var timeouts := [TIMEOUTS_PER_HALF, TIMEOUTS_PER_HALF]
var _warning_due := false
var _warned := false

func reset() -> void:
	half = 1
	final = false
	_reset_half()

func _reset_half() -> void:
	remaining = half_length
	play_clock = PLAY_CLOCK
	running_between_plays = false
	timeouts = [timeout_limit, timeout_limit]
	_warning_due = false
	_warned = false

func expired() -> bool:
	return remaining <= 0.0

## Advance. live/presnap describe the current world phase.
## Returns true when the play clock just ran out (caller snaps).
func tick(dt: float, live: bool, presnap: bool) -> bool:
	if final:
		return false
	if live or (running_between_plays and not _warning_due):
		var before := remaining
		remaining = maxf(0.0, remaining - dt)
		if not _warned and before >= WARNING_TIME and remaining < WARNING_TIME:
			_warning_due = true
			if not live:
				remaining = WARNING_TIME
	if presnap:
		play_clock = maxf(0.0, play_clock - dt)
		return play_clock <= 0.0
	return false

func take_warning() -> bool:
	if not _warning_due:
		return false
	_warning_due = false
	_warned = true
	running_between_plays = false
	return true

func spend_timeout(team: int) -> bool:
	if final or team < 0 or team >= timeouts.size() or timeouts[team] == 0:
		return false
	timeouts[team] -= 1
	running_between_plays = false
	return true

func new_play() -> void:
	play_clock = PLAY_CLOCK

func start_next_half() -> void:
	half += 1
	_reset_half()

func label() -> String:
	if final:
		return "FINAL"
	var s := int(ceil(remaining))
	return "H%d %d:%02d" % [half, s / 60, s % 60]
