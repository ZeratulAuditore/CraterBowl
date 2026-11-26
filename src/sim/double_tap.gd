extends RefCounted
## Double-tap detector (#142): a set defender breaks stance with two Space
## presses within `T.STANCE_DOUBLE_TAP`. Resolved on the pressing machine, so the
## wire still carries one `snap` action (protocol unchanged). Pure: callers pass time.

const T := preload("res://src/sim/tuning.gd")

var _last := -INF

## Register a press at `now` (seconds). True when it completes a double-tap;
## the pair is consumed, so a third quick press starts a new one.
func press(now: float, window: float = T.STANCE_DOUBLE_TAP) -> bool:
	if now - _last <= window:
		_last = -INF
		return true
	_last = now
	return false

func reset() -> void:
	_last = -INF
