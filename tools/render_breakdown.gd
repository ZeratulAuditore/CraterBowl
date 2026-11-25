extends SceneTree
## Diagnosis: per-node-group triangles + shadow casters + lights for the real scene.
## Needs a real renderer (Xvfb):  env -u WAYLAND_DISPLAY xvfb-run -a godot --path . --display-driver x11 \
##   --rendering-driver opengl3 -s res://tools/render_breakdown.gd -- --gfx=high --profile-file=user://test_bd.json
## See docs/optimization/README.md ("Finding the cost").
var m; var f := 0
func _initialize() -> void:
	m = load("res://scenes/main.tscn").instantiate(); root.add_child(m)
	process_frame.connect(func():
		f += 1
		if f < 20: return
		var groups := {}
		for n in _walk(m):
			if not (n is GeometryInstance3D) or not n.is_visible_in_tree(): continue
			var t := 0
			if n is MeshInstance3D and n.mesh: t = _tris(n.mesh)
			elif n is MultiMeshInstance3D and n.multimesh and n.multimesh.mesh: t = _tris(n.multimesh.mesh) * n.multimesh.instance_count
			var key := "%s<%s>" % [str(n.name).rstrip("0123456789").trim_prefix("@").get_slice("@", 0), n.get_class()]
			var p := str(n.get_parent().name) if not str(n.name).begins_with("@") else str(n.get_parent().name)
			key = p.rstrip("0123456789") + "/" + key
			var g = groups.get(key, [0, 0, 0])
			g[0] += 1; g[1] += t; g[2] += 1 if n.cast_shadow != 0 else 0
			groups[key] = g
		var ks := groups.keys()
		ks.sort_custom(func(a, b): return groups[a][1] > groups[b][1])
		for k in ks.slice(0, 30): print("%-50s n=%3d tris=%7d casters=%d" % [k, groups[k][0], groups[k][1], groups[k][2]])
		var ls := []
		for n in _walk(m):
			if n is Light3D: ls.append("%s shadow=%s" % [n.get_class(), n.shadow_enabled])
		print("lights: ", ls.size(), " ", ls.slice(0, 12))
		quit())
func _tris(mesh: Mesh) -> int:
	if mesh is PrimitiveMesh:
		var a: Array = mesh.get_mesh_arrays(); var i = a[Mesh.ARRAY_INDEX]
		return i.size() / 3 if i != null and i.size() > 0 else a[Mesh.ARRAY_VERTEX].size() / 3
	if mesh.has_meta("tris"): return int(mesh.get_meta("tris"))
	var n := 0
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		if a.size() > 0:
			var i = a[Mesh.ARRAY_INDEX]; n += i.size() / 3 if i != null and i.size() > 0 else a[Mesh.ARRAY_VERTEX].size() / 3
	return n
func _walk(n: Node) -> Array:
	var o := [n]
	for c in n.get_children(): o.append_array(_walk(c))
	return o
