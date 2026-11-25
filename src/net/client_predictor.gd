extends RefCounted
## Client-side prediction for the local athlete. Pure.

const MAX_PENDING := 240

var seq := 0
var pending: Array = []   # [[seq, dir, sprint, dt], ...]

## Record a new local input; returns its seq. Caller steps the athlete locally.
func record(dir: Vector2, sprint: bool, dt: float) -> int:
	seq += 1
	pending.append([seq, dir, sprint, dt])
	if pending.size() > MAX_PENDING:
		pending.pop_front()
	return seq

## Reset athlete to authoritative state (already applied by caller), drop acked
## inputs and replay the rest on top.
func reconcile(athlete, acked_seq: int) -> void:
	while not pending.is_empty() and pending[0][0] <= acked_seq:
		pending.pop_front()
	for p in pending:
		athlete.step(p[1], p[2], p[3])
