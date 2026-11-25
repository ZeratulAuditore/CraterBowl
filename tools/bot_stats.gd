extends SceneTree
## Dev tool: simulate an all-bot game and print outcome stats.
## godot --headless --path . -s res://tools/bot_stats.gd [-- --minutes=4]
const World := preload("res://src/sim/world.gd")
const Match := preload("res://src/sim/match.gd")
const Roster := preload("res://src/sim/roster.gd")
const AI := preload("res://src/sim/ai.gd")
func _initialize() -> void:
	var minutes := 4.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--minutes="): minutes = float(a.split("=")[1])
	var w := World.new(); Roster.new().build(w)
	var m := Match.new(w); m.start(1 if OS.get_cmdline_user_args().has("--flip") else 0, 25.0)
	var ai := AI.new()
	var ev := {}
	var gains := []
	var los0 := [25.0]
	w.event.connect(func(n, d):
		ev[n] = ev.get(n, 0) + 1
		if n == "tackle" or n == "out_of_bounds": gains.append(snappedf(d["spot"].y - los0[0], 0.1)))
	var dead_t := 0.0
	for i in int(minutes * 60.0 * 60):
		m.tick(1.0 / 60); ai.presnap_tick(w, [], 1.0 / 60, m.downs.down, m.downs.distance())
		w.step(ai.think(w, []), 1.0 / 60)
		if w.phase == World.Phase.DEAD:
			dead_t += 1.0 / 60
			if dead_t > 0.5: m.next_play(); dead_t = 0.0; los0[0] = w.los_y
	var throws: int = ev.get("throw", 0)
	print("events: ", ev)
	print("completion %%: %.0f" % (100.0 * ev.get("catch", 0) / maxf(1, throws)))
	print("gains: ", gains)
	print("score: ", m.score)
	quit()
