extends RefCounted
## Game and play clocks, warning and team timeouts. Pure.
## #130: every match plays four quarters (Q1-Q4); there is no halves format.

const QUARTER_LENGTH := 150.0   # 4 x 2:30 = the 10 minutes the old two 5:00 halves ran
const HALVES := 2
const PLAY_CLOCK := 20.0
const WARNING_TIME := 60.0
const TIMEOUTS_PER_HALF := 3
const SMALL_MATCH_TIMEOUTS := 2

## Derived from `quarter` (Q1-Q2 = 1st half, Q3-Q4 = 2nd), so the two can't disagree.
## Setting it (an old halves-format snapshot) moves to the first quarter of that half.
var half: int:
	get: return 1 if quarter <= 2 else 2
	set(v): quarter = 1 if v <= 1 else 3
var quarter := 1
## A zero or negative length (an old halves-format host or caller) falls back to the default.
var quarter_length := QUARTER_LENGTH:
	set(v): quarter_length = v if v > 0.0 else QUARTER_LENGTH
var remaining := QUARTER_LENGTH
var play_clock := PLAY_CLOCK
var final := false
var running_between_plays := false
var timeout_limit := TIMEOUTS_PER_HALF
var timeouts := [TIMEOUTS_PER_HALF, TIMEOUTS_PER_HALF]
var _warning_due := false
var _warned := false

func reset() -> void:
	quarter = 1
	final = false
	_reset_half()

func _reset_half() -> void:
	timeouts = [timeout_limit, timeout_limit]
	_warning_due = false
	_warned = false
	_reset_period()

func _reset_period() -> void:
	remaining = quarter_length
	play_clock = PLAY_CLOCK
	running_between_plays = false

func advance_midhalf_quarter() -> bool:
	if quarter % 2 == 0:
		return false
	quarter += 1
	_reset_period()
	return true

## 0-based period: Q1..Q4 -> 0..3.
func period() -> int:
	return quarter - 1

## Seconds left in the half: the end-of-half situation (prevent defense) is the end of Q2/Q4,
## not of every quarter (#130).
func half_remaining() -> float:
	return remaining + (0.0 if quarter % 2 == 0 else quarter_length)

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
		var last_period_of_half := quarter % 2 == 0
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
	quarter = 3
	_reset_half()

func label() -> String:
	if final:
		return "FINAL"
	var s := int(ceil(remaining))
	return "Q%d %d:%02d" % [clampi(quarter, 1, 4), s / 60, s % 60]
