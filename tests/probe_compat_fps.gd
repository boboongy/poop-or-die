extends SceneTree
## Web-build FPS probe (windowed, real time; not run by run.sh): one level from the default camera, FPS over 3 s with each
## expensive setting switched off in turn. Run it with the web build's renderer:
##   "<console exe>" --path . --rendering-method gl_compatibility --script tests/probe_compat_fps.gd -- level=3
const Progress := preload("res://scripts/progress.gd")
const Intro := preload("res://scripts/intro.gd")


func _fps() -> float:
	for i in 20:
		await process_frame
	var frames := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		await process_frame
		frames += 1
	return frames / 3.0


func _init() -> void:
	var n := 3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			n = int(a.substr(6))
	get_root().size = Vector2i(1280, 720)
	Intro.enabled = false
	Progress.level = n
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	for i in 120:
		await process_frame
	var vp := get_root()
	var env: Environment = (lvl.find_child("WorldEnvironment", true, false) as WorldEnvironment).environment
	var lights := lvl.find_children("*", "Light3D", true, false)
	var shadowed := lights.filter(func(l): return l.shadow_enabled)
	var skinned := lvl.find_children("*", "Skeleton3D", true, false)
	print("lights %d, shadowed %d, skeletons %d" % [lights.size(), shadowed.size(), skinned.size()])
	print("default           %.1f FPS" % await _fps())
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.anisotropic_filtering_level = Viewport.ANISOTROPY_DISABLED
	print("+ no MSAA/aniso   %.1f FPS" % await _fps())
	env.glow_enabled = false
	env.ssao_enabled = false
	print("+ no glow/ssao    %.1f FPS" % await _fps())
	for l in shadowed:
		l.shadow_enabled = false
	print("+ no shadows      %.1f FPS" % await _fps())
	vp.scaling_3d_scale = 0.75
	print("+ 3D scale 0.75   %.1f FPS" % await _fps())
	for s in skinned:
		for m in (s as Node).find_children("*", "MeshInstance3D", true, false):
			m.visible = false
	print("+ no characters   %.1f FPS" % await _fps())
	quit()
