extends SceneTree
## Desktop FPS probe (Forward+, a REAL window, REAL time; not run by run.sh): one level from the default camera with the
## settings given on the command line. This is the only way to measure what the owner sees; the `shot_*` tests print a single
## frame's FPS, which is meaningless, and `tools/web_fps.py` is Chrome-only.
##   "<console exe>" --path . --script tests/probe_fullscreen_fps.gd -- res=1920x1080 [level=1] [seconds=10] [runs=1]
##       [fullscreen=1] [vsync=1] [msaa=4|2|0] [fxaa=1] [ssr=0] [ssao=0] [sdfgi=0] [glow=0] [fog=20] [scale=0.8]
##       [shadows=all|none|<n>] [amb=1.2] [out=shot.png]
## NEVER add --fixed-fps (it advances the game a fixed step per frame without waiting for the clock, so the frame rate it
## prints is the CPU's, not the GPU's) and NEVER --headless (the whole point is the real GPU).
## Vsync is OFF by default, so a result above 60 still shows its headroom; `vsync=1` measures what the shipped game does.
## The first 90 frames are thrown away: shader compilation makes the first second far slower than the game ever is again.
const Progress := preload("res://scripts/progress.gd")
const Intro := preload("res://scripts/intro.gd")

const WARMUP_FRAMES := 90

var _draw_calls: Array[float] = []
var _objects: Array[float] = []
## Where the frame time goes. 2026-10-10: turning MSAA, SSR, SSAO, fog and all 10 shadows off left 1080p at ~17 FPS, so the
## GPU settings were never the cap; these two monitors say how much of the 57 ms frame is the game's own CPU work.
var _cpu_process: Array[float] = []
var _cpu_physics: Array[float] = []


func _init() -> void:
	var opt := {"res": "1920x1080", "level": "1", "seconds": "10", "runs": "1", "shadows": ""}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			opt[kv[0]] = kv[1]
	var wh: PackedStringArray = String(opt.res).split("x")
	var size := Vector2i(int(wh[0]), int(wh[1]))
	get_root().size = size
	DisplayServer.window_set_size(size)
	if opt.has("fullscreen"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if not opt.has("vsync"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	Intro.enabled = false # the measurement must be the same view every run; the intro moves the camera
	Progress.level = int(opt.level)
	var lvl: Node = load("res://scenes/level_toilet.tscn").instantiate()
	await process_frame
	get_root().add_child(lvl)
	for i in 30:
		await process_frame

	var vp := get_root()
	var env: Environment = (lvl.find_child("WorldEnvironment", true, false) as WorldEnvironment).environment
	var lights: Array = lvl.find_children("*", "SpotLight3D", true, false)
	_apply(opt, vp, env, lights, lvl)

	var seconds := float(opt.seconds)
	var runs := int(opt.runs)
	var avgs: Array[float] = []
	for r in runs:
		for i in WARMUP_FRAMES:
			await process_frame
		var fps_each: Array[float] = []
		var frames := 0
		var t0 := Time.get_ticks_usec()
		var last := t0
		while (Time.get_ticks_usec() - t0) < int(seconds * 1000000.0):
			await process_frame
			var now := Time.get_ticks_usec()
			var dt := now - last
			last = now
			if dt > 0:
				fps_each.append(1000000.0 / float(dt))
			# One snapshot at the end read 7549 draw calls in one run and 957 in the next (2026-10-10): sample every frame.
			_draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			_objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
			_cpu_process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			_cpu_physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			frames += 1
		var elapsed := float(Time.get_ticks_usec() - t0) / 1000000.0
		var avg := frames / elapsed
		avgs.append(avg)
		fps_each.sort()
		var median := fps_each[fps_each.size() / 2] if not fps_each.is_empty() else 0.0
		var p5 := fps_each[int(fps_each.size() * 0.05)] if not fps_each.is_empty() else 0.0
		var low := fps_each[0] if not fps_each.is_empty() else 0.0
		print("PROBE run %d/%d  avg %.1f  median %.1f  p5 %.1f  min %.1f  (%d frames in %.1f s)" % [
			r + 1, runs, avg, median, p5, low, frames, elapsed])

	if opt.has("out"):
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(opt.out)
	var shadowed: int = lights.filter(func(l): return l.shadow_enabled).size()
	avgs.sort()
	_draw_calls.sort()
	_objects.sort()
	_cpu_process.sort()
	_cpu_physics.sort()
	var frame_ms := 1000.0 / avgs[avgs.size() / 2] if not avgs.is_empty() else 0.0
	var proc_ms: float = _cpu_process[_cpu_process.size() / 2]
	var phys_ms: float = _cpu_physics[_cpu_physics.size() / 2]
	print("PROBE CPU frame %.1f ms = process %.1f + physics %.1f (%.0f %% of the frame) -> the rest is the GPU, nodes %d" % [
		frame_ms, proc_ms, phys_ms, 100.0 * (proc_ms + phys_ms) / maxf(frame_ms, 0.001),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	print("PROBE draw calls median %d (min %d, max %d), objects median %d, primitives %d" % [
		_draw_calls[_draw_calls.size() / 2], _draw_calls[0], _draw_calls[-1],
		_objects[_objects.size() / 2],
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	# The enum ints are a trap in a log read days later: MSAA_4X is 2, MSAA_2X is 1 (2026-10-10).
	var msaa_name: String = ["off", "2x", "4x", "8x"][vp.msaa_3d]
	print("PROBE SETTINGS %dx%d msaa %s fxaa %s scale %.2f sdfgi %s ssr %s ssao %s fog %s len %.0f glow %s lights %d shadowed %d renderer %s" % [
		size.x, size.y, msaa_name, vp.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA, vp.scaling_3d_scale, env.sdfgi_enabled, env.ssr_enabled,
		env.ssao_enabled, env.volumetric_fog_enabled, env.volumetric_fog_length, env.glow_enabled, lights.size(),
		shadowed, RenderingServer.get_current_rendering_method()])
	print("PROBE RESULT %s -> median of %d run(s) %.1f FPS" % [
		" ".join(OS.get_cmdline_user_args()), avgs.size(), avgs[avgs.size() / 2]])
	quit()


## Every ladder step from PERF_PLAN.md, applied AFTER the level's own _ready (liminal_lighting.gd sets MSAA and the
## environment there, so an override written earlier would be wiped).
func _apply(opt: Dictionary, vp: Viewport, env: Environment, lights: Array, lvl: Node) -> void:
	if opt.has("msaa"):
		var m := {"4": Viewport.MSAA_4X, "2": Viewport.MSAA_2X, "0": Viewport.MSAA_DISABLED}
		vp.msaa_3d = m.get(opt.msaa, Viewport.MSAA_DISABLED)
	if opt.has("fxaa"):
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if opt.fxaa == "1" else Viewport.SCREEN_SPACE_AA_DISABLED
	if opt.has("ssr"):
		env.ssr_enabled = opt.ssr == "1"
	if opt.has("ssao"):
		env.ssao_enabled = opt.ssao == "1"
	if opt.has("sdfgi"):
		env.sdfgi_enabled = opt.sdfgi == "1"
	if opt.has("glow"):
		env.glow_enabled = opt.glow == "1"
	if opt.has("fog"):
		var length := float(opt.fog)
		env.volumetric_fog_enabled = length > 0.0
		if length > 0.0:
			env.volumetric_fog_length = length
	if opt.has("scale"):
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = float(opt.scale)
	if opt.has("amb"): # SDFGI off leaves the characters near-black without an ambient boost (COMPAT_AMBIENT does this for web)
		env.ambient_light_energy = float(opt.amb)
	if opt.shadows != "": # "all", "none", or a number: the N spots nearest Bob keep their shadow
		var keep := -1
		if opt.shadows == "none":
			keep = 0
		elif opt.shadows != "all":
			keep = int(opt.shadows)
		if keep >= 0:
			var bob: Node3D = lvl.get_tree().get_first_node_in_group("player")
			var from: Node3D = bob if bob != null else vp.get_camera_3d()
			var sorted: Array = lights.duplicate()
			if from != null:
				sorted.sort_custom(func(a, b): return a.global_position.distance_squared_to(from.global_position) < b.global_position.distance_squared_to(from.global_position))
			for i in sorted.size():
				(sorted[i] as SpotLight3D).shadow_enabled = i < keep
		else:
			for l in lights:
				(l as SpotLight3D).shadow_enabled = true
