extends SceneTree
## Web-build FPS probe (windowed, real time; not run by run.sh): one level from the default camera, the FPS over 4 s with the
## settings given on the command line. Run it with the web build's renderer, one process per setting:
##   "<console exe>" --path . --rendering-method gl_compatibility --script tests/probe_compat_fps.gd -- level=3 [shadows=all|near|none]
##   [scale=0.75] [msaa=0|1] [chars=0] [range=7]
const Progress := preload("res://scripts/progress.gd")
const Intro := preload("res://scripts/intro.gd")


func _init() -> void:
	var opt := {"level": "3", "shadows": "", "scale": "", "msaa": "", "chars": "1", "range": ""}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			opt[kv[0]] = kv[1]
	get_root().size = Vector2i(1280, 720)
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
