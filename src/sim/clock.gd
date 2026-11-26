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
var quarter := 1
var quarter_length := 0.0   # zero selects halves
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
	quarter = 1
	final = false
	_reset_half()

func uses_quarters() -> bool:
	return quarter_length > 0.0

func _reset_half() -> void:
	timeouts = [timeout_limit, timeout_limit]
	_warning_due = false
	_warned = false
	_reset_period()

func _reset_period() -> void:
	remaining = quarter_length if uses_quarters() else half_length
	play_clock = PLAY_CLOCK
	running_between_plays = false

func advance_midhalf_quarter() -> bool:
	if not uses_quarters() or quarter % 2 == 0:
		return false
	quarter += 1
	_reset_period()
	return true

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
		var last_period_of_half := not uses_quarters() or quarter % 2 == 0
		if last_period_of_half and not _warned and before >= WARNING_TIME and remaining < WARNING_TIME:
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
	quarter = 3
	_reset_half()

func label() -> String:
	if final:
		return "FINAL"
	var s := int(ceil(remaining))
	var period := "Q%d" % quarter if uses_quarters() else "H%d" % half
	return "%s %d:%02d" % [period, s / 60, s % 60]
