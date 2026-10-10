extends SceneTree
## Web-build FPS probe (windowed, real time; not run by run.sh): one level from the default camera, the FPS over 4 s with the
## settings given on the command line. Run it with the web build's renderer, one process per setting:
##   "<console exe>" --path . --rendering-method gl_compatibility --script tests/probe_compat_fps.gd -- level=3 [shadows=all|near|none]
##   [scale=0.75] [msaa=0|1] [chars=0] [range=7] [size=1920x1080] [far=18]
## ALWAYS state the window size with the number, but do NOT expect it to change much: measured 2026-10-11 at
## `shadows=near scale=0.75`, L3 ran 46.5 FPS at 1280x720 and 46.8 at 1920x1080, so this frame is NOT fill-rate bound and
## the lever is the DRAW-CALL count (PERF_PLAN.md "Web speed 2"). `shadows=none` alone is undone every 0.25 s by
## liminal_lighting.gd's `_update_shadow_light()`: use `lights=noshadow`, which stops that node's `_process` first.
## Every run prints a PROBE dist line (how many Jijios sit in each distance band from the default camera).
const Progress := preload("res://scripts/progress.gd")
const Intro := preload("res://scripts/intro.gd")


func _init() -> void:
	var opt := {"level": "3", "shadows": "", "scale": "", "msaa": "", "chars": "1", "range": "", "size": "1280x720"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			opt[kv[0]] = kv[1]
	var wh: PackedStringArray = String(opt.size).split("x")
	get_root().size = Vector2i(int(wh[0]), int(wh[1]))
	Intro.enabled = false
	Progress.level = int(opt.level)
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	for i in 60:
		await process_frame
	var vp := get_root()
	var lights := lvl.find_children("*", "SpotLight3D", true, false)
	if opt.shadows == "none":
		for l in lights:
			l.shadow_enabled = false
	elif opt.shadows == "near": # only the spot light nearest Bob casts shadows
		var bob: Node3D = lvl.get_tree().get_first_node_in_group("player")
		var best: SpotLight3D = null
		for l in lights:
			l.shadow_enabled = false
			if best == null or l.global_position.distance_to(bob.global_position) < best.global_position.distance_to(bob.global_position):
				best = l
		best.shadow_enabled = true
	elif opt.shadows == "all":
		for l in lights:
			l.shadow_enabled = true
	if opt.range != "":
		for l in lights:
			l.spot_range = float(opt.range)
	if opt.has("lod"):
		vp.mesh_lod_threshold = float(opt.lod)
	var env: Environment = (lvl.find_child("WorldEnvironment", true, false) as WorldEnvironment).environment
	if opt.has("amb"): # look tuning: ambient energy, saturation, contrast, glow intensity, tonemap exposure
		env.ambient_light_energy = float(opt.amb)
	if opt.has("sat"):
		env.adjustment_saturation = float(opt.sat)
	if opt.has("con"):
		env.adjustment_contrast = float(opt.con)
	if opt.has("glow"):
		env.glow_intensity = float(opt.glow)
	if opt.has("energy"):
		for l in lights:
			l.light_energy = float(opt.energy)
	if opt.has("exp"):
		env.tonemap_exposure = float(opt.exp)
	if opt.has("lights"): # lights=0: every spot hidden; lights=noshadow: no spot casts shadows (the lighting script's update stopped)
		var ll := lvl.find_child("Lighting", false, false)
		if ll != null:
			ll.set_process(false)
		for l in lights:
			l.shadow_enabled = false
			if opt.lights == "0":
				l.visible = false
	if opt.has("hide"): # hide=FloodWater: every node with that name
		for n in lvl.find_children(opt.hide, "Node3D", true, false):
			(n as Node3D).visible = false
			print("PROBE hid ", n.get_path())
	if opt.scale != "":
		vp.scaling_3d_scale = float(opt.scale)
	if opt.msaa != "":
		vp.msaa_3d = Viewport.MSAA_4X if opt.msaa == "1" else Viewport.MSAA_DISABLED
	if opt.chars == "0":
		for s in lvl.find_children("*", "Skeleton3D", true, false):
			for m in (s as Node).find_children("*", "MeshInstance3D", true, false):
				m.visible = false
	if opt.chars == "offscreen": # hide every character whose box is outside the default camera's view
		var cam := vp.get_camera_3d()
		var hidden := 0
		for s in lvl.find_children("*", "Skeleton3D", true, false):
			var p: Vector3 = (s as Node3D).global_position + Vector3.UP
			if not cam.is_position_in_frustum(p):
				hidden += 1
				for m in (s as Node).find_children("*", "MeshInstance3D", true, false):
					m.visible = false
		print("PROBE offscreen hidden %d" % hidden)
	if opt.chars == "nolight": # characters on layer 2, lights only on layer 1: characters get ambient light only
		for s in lvl.find_children("*", "Skeleton3D", true, false):
			for m in (s as Node).find_children("*", "MeshInstance3D", true, false):
				(m as VisualInstance3D).layers = 2
		for l in lights:
			l.light_cull_mask = 1
	if opt.chars == "still":
		for ap in lvl.find_children("*", "AnimationPlayer", true, false):
			(ap as AnimationPlayer).pause()
	if opt.chars == "info":
		var verts := 0
		var surfs := 0
		var meshes := 0
		for s in lvl.find_children("*", "Skeleton3D", true, false):
			for m in (s as Node).find_children("*", "MeshInstance3D", true, false):
				var mesh: Mesh = (m as MeshInstance3D).mesh
				if mesh == null or not m.visible:
					continue
				meshes += 1
				for i in mesh.get_surface_count():
					surfs += 1
					verts += mesh.surface_get_array_len(i)
		var one: Node = lvl.find_children("*", "Skeleton3D", true, false)[1]
		for m in one.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (m as MeshInstance3D).mesh
			var v := 0
			for i in mesh.get_surface_count():
				v += mesh.surface_get_array_len(i)
			print("PROBE  %s  surfaces %d  verts %d  visible %s  skin %s" % [m.name, mesh.get_surface_count(), v, m.visible, m.skin])
			for i in mesh.get_surface_count():
				var mat := (m as MeshInstance3D).get_active_material(i) as StandardMaterial3D
				print("PROBE     %s tex %s col %s cull %d transp %d rough %.2f emis %s" % [mat.resource_name, mat.albedo_texture,
					mat.albedo_color, mat.cull_mode, mat.transparency, mat.roughness, mat.emission_enabled])
		print("PROBE chars: %d skeletons, %d meshes, %d surfaces, %d vertices" % [
			lvl.find_children("*", "Skeleton3D", true, false).size(), meshes, surfs, verts])
	var aps: Array = []
	if opt.chars == "third": # every AnimationPlayer but Bob's advanced by hand on every 3rd frame, staggered
		for ap in lvl.find_children("*", "AnimationPlayer", true, false):
			if (ap as Node).find_parent("Player") == null:
				(ap as AnimationPlayer).callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				aps.append(ap)
	# Rung 1 of the web ladder: hide every Jijio further than `far` metres from the default camera. The dist line is always
	# printed, so a run also says how many characters such a cull would remove on this level.
	var cam2 := vp.get_camera_3d()
	var jijios: Array = lvl.get_tree().get_nodes_in_group("jijio")
	if cam2 != null:
		var bands := [6.0, 12.0, 18.0, 25.0]
		var counts := [0, 0, 0, 0, 0]
		for npc in jijios:
			var d: float = cam2.global_position.distance_to((npc as Node3D).global_position)
			var b := bands.size()
			for i in bands.size():
				if d < bands[i]:
					b = i
					break
			counts[b] += 1
		print("PROBE dist %d Jijios: <6m %d, 6-12m %d, 12-18m %d, 18-25m %d, >25m %d" % [jijios.size(),
			counts[0], counts[1], counts[2], counts[3], counts[4]])
		if opt.has("far"):
			var limit := float(opt.far)
			var hidden := 0
			for npc in jijios:
				if cam2.global_position.distance_to((npc as Node3D).global_position) > limit:
					(npc as Node3D).visible = false
					hidden += 1
			print("PROBE far=%.0f hid %d of %d Jijios" % [limit, hidden, jijios.size()])
	if opt.has("scene"): # scene=info: the STATIC meshes (everything not under a Skeleton3D), grouped by their top ancestor
		var by_group := {}
		var total := 0
		var surfs2 := 0
		for m in lvl.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null or mi.skin != null or not mi.is_visible_in_tree():
				continue
			var top: Node = mi
			while top.get_parent() != null and top.get_parent() != lvl:
				top = top.get_parent()
			var k: String = "%s/%s" % [top.name, mi.get_parent().name]
			by_group[k] = by_group.get(k, 0) + mi.mesh.get_surface_count()
			total += 1
			surfs2 += mi.mesh.get_surface_count()
		var keys: Array = by_group.keys()
		keys.sort_custom(func(a, b): return by_group[a] > by_group[b])
		for k in keys.slice(0, 12):
			print("PROBE scene  %-44s %d surfaces" % [k, by_group[k]])
		print("PROBE scene: %d static meshes, %d surfaces, %d groups" % [total, surfs2, by_group.size()])
	var tick := 0
	if opt.has("webprobe"):
		lvl.add_child(load("res://scripts/web_probe.gd").new())
	for i in 60:
		await process_frame
	var frames := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000:
		await process_frame
		frames += 1
		tick += 1
		for i in aps.size():
			if (i + tick) % 3 == 0:
				(aps[i] as AnimationPlayer).advance(0.05)
	if opt.has("out"): # a screenshot after the measurement
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(opt.out)
	var shadowed := lights.filter(func(l): return l.shadow_enabled).size()
	print("PROBE draw calls %d, objects %d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	print("PROBE %s -> %.1f FPS (lights %d, shadowed %d, msaa %d, scale %.2f)" % [
		" ".join(OS.get_cmdline_user_args()), frames / 4.0, lights.size(), shadowed, vp.msaa_3d, vp.scaling_3d_scale])
	quit()
