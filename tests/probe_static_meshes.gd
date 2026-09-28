extends SceneTree
## Web speed probe (not run by run.sh): what the level's scenery is made of, the source of most draw calls in the web build.
## Lists visible MeshInstance3Ds outside characters grouped by name prefix, with surfaces, materials and whether they move.
##   "<console exe>" --headless --path . --script tests/probe_static_meshes.gd -- level=3
const Progress := preload("res://scripts/progress.gd")
const Intro := preload("res://scripts/intro.gd")


func _init() -> void:
	var level := "3"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			level = a.split("=")[1]
	Intro.enabled = false
	Progress.level = int(level)
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	for i in 30:
		await process_frame
	var groups := {}
	var mats := {}
	var total := 0
	var surfs := 0
	for m in lvl.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or mi.find_parent("*Jijio*") != null or mi.skin != null:
			continue
		var prefix := String(mi.name).rstrip("0123456789_.")
		var parent_name := String(mi.get_parent().name)
		var key := "%s  (parent %s, script %s)" % [prefix, parent_name.rstrip("0123456789_."), mi.get_parent().get_script() != null]
		var g: Array = groups.get(key, [0, 0])
		g[0] += 1
		g[1] += mi.mesh.get_surface_count()
		groups[key] = g
		total += 1
		surfs += mi.mesh.get_surface_count()
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			mats[mat] = true
	var keys := groups.keys()
	keys.sort_custom(func(a, b): return groups[a][1] > groups[b][1])
	for k in keys.slice(0, 40):
		print("PROBE %4d meshes %4d surfaces  %s" % [groups[k][0], groups[k][1], k])
	print("PROBE total %d meshes, %d surfaces, %d materials" % [total, surfs, mats.size()])
	quit()
