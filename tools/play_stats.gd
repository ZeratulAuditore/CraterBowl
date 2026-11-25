extends SceneTree
## Dev tool: per-play pass outcomes in an all-bot game.
const World := preload("res://src/sim/world.gd")
const Match := preload("res://src/sim/match.gd")
const Roster := preload("res://src/sim/roster.gd")
const AI := preload("res://src/sim/ai.gd")
func _initialize() -> void:
	var w := World.new(); Roster.new().build(w)
	var m := Match.new(w); m.start(0, 25.0)
	var ai := AI.new()
	var per := {}
	w.event.connect(func(n, d):
		if n in ["catch", "interception", "breakup", "incomplete", "throw"]:
			var k: String = w.play_name
			if not per.has(k): per[k] = {}
			per[k][n] = per[k].get(n, 0) + 1
		if n == "throw":
			per[w.play_name]["air"] = per[w.play_name].get("air", 0.0) + Vector2(d["target"]).distance_to(w.throw_origin))
	var dead_t := 0.0
	for i in int(10.0 * 60 * 60):
		m.tick(1.0 / 60); ai.presnap_tick(w, [], 1.0 / 60, m.downs.down, m.downs.distance())
		w.step(ai.think(w, []), 1.0 / 60)
		if w.phase == World.Phase.DEAD:
			dead_t += 1.0 / 60
			if dead_t > 0.5: m.next_play(); dead_t = 0.0
	for k in per:
		var p: Dictionary = per[k]
		print("%-10s throws=%d catch=%d int=%d brk=%d avg_air=%.1f" % [k, p.get("throw", 0), p.get("catch", 0), p.get("interception", 0), p.get("breakup", 0), p.get("air", 0.0) / maxf(1, p.get("throw", 0))])
	quit()
