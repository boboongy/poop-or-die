extends SceneTree
## The automatic desktop quality tier (owner's option A, PERF_PLAN.md "MEASURED" 2026-10-10). The FPS win itself can only be
## measured in a real window (tests/probe_fullscreen_fps.gd); what this test guards is the part that can silently rot:
## MEDIUM must drop the whole per-pixel stack AND keep the look the owner's video shows (haze, glow, all 10 shadows), the
## verdict must stick for the whole launch (a tier that re-decides could switch quality mid-recording), and HIGH must still
## be the untouched full look. Headless reports ~60 FPS under --fixed-fps, so a plain boot must stay HIGH: the tier must
## never fire in the rest of the suite.
##   timeout 120 "<console exe>" --headless --path . --fixed-fps 60 --script tests/test_perf_tier.gd
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Lighting := preload("res://scripts/liminal_lighting.gd")


func _init() -> void:
	seed(1)
	Progress.level = 1
	Lighting.tier_locked = false # a static: another test in the same process could have left a verdict behind
	Lighting.tier = Lighting.Quality.HIGH
	var lvl := T.level(self)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	var light: Node = lvl.find_child("Lighting", false, false)
	T.check(light != null, "the level has a Lighting node")
	var env: Environment = (lvl.find_child("WorldEnvironment", true, false) as WorldEnvironment).environment
	var spots: Array = lvl.find_children("*", "SpotLight3D", true, false)
	T.check(spots.size() >= 8, "the ceiling grid has its spot lights (%d)" % spots.size())

	# A plain boot must not change anything: headless is fast, so the sampled median is above the bar.
	T.check(not Lighting.is_compat(), "headless takes the desktop path, not the web one")
	T.check(env.sdfgi_enabled, "HIGH keeps SDFGI (the full look is untouched)")
	T.check(env.volumetric_fog_length == 40.0, "HIGH keeps the 40 m haze")

	# MEDIUM: the whole per-pixel stack off, everything that carries the look kept.
	light.apply_quality(Lighting.Quality.MEDIUM)
	await process_frame
	T.check(not env.sdfgi_enabled, "MEDIUM drops SDFGI")
	T.check(not env.ssr_enabled, "MEDIUM drops SSR")
	T.check(not env.ssao_enabled, "MEDIUM drops SSAO")
	T.check(env.volumetric_fog_enabled, "MEDIUM KEEPS the green haze")
	T.check(env.volumetric_fog_length == Lighting.PERF_FOG_LENGTH, "MEDIUM shortens the haze to %.0f m" % Lighting.PERF_FOG_LENGTH)
	T.check(env.glow_enabled, "MEDIUM KEEPS the glow")
	var lit: int = spots.filter(func(s): return s.shadow_enabled).size()
	T.check(lit == spots.size(), "MEDIUM KEEPS every ceiling-grid shadow (%d of %d)" % [lit, spots.size()])
	# Without SDFGI's bounce the characters go near-black (owner 2026-09-28, "so shadowed"): ambient must take over.
	T.check(is_equal_approx(env.ambient_light_energy, light.ambient_energy * Lighting.PERF_AMBIENT),
		"MEDIUM compensates the lost bounce with ambient (%.2f)" % env.ambient_light_energy)
	T.check(light.get_viewport().scaling_3d_scale == 1.0, "MEDIUM does NOT need a render-scale drop")

	# LOW is the last resort, reachable only with --perf=low.
	light.apply_quality(Lighting.Quality.LOW)
	await process_frame
	T.check(not env.volumetric_fog_enabled, "LOW drops the haze too")
	T.check(spots.filter(func(s): return s.shadow_enabled).is_empty(), "LOW drops the shadows")
	# is_equal_approx, not ==: a float read back from a Godot property is float32, so 0.8 comes back as 0.80000001 (2026-10-10).
	T.check(is_equal_approx(light.get_viewport().scaling_3d_scale, Lighting.LOW_SCALE), "LOW draws 3D at %.2f" % Lighting.LOW_SCALE)

	# The verdict sticks: a retry or the next level reloads this scene and must NOT measure again.
	Lighting.tier = Lighting.Quality.MEDIUM
	Lighting.tier_locked = true
	lvl.queue_free()
	await process_frame
	var again := T.level(self)
	await T.wait(self, 0.5)
	again._time_left = 100000.0
	var light2: Node = again.find_child("Lighting", false, false)
	var env2: Environment = (again.find_child("WorldEnvironment", true, false) as WorldEnvironment).environment
	T.check(not light2._measuring, "a locked tier is not measured again (no mid-recording switch)")
	T.check(light2.quality == Lighting.Quality.MEDIUM, "the reloaded level comes up in the locked tier")
	T.check(not env2.sdfgi_enabled, "the locked tier is really applied after the reload")
	T.check(Lighting._forced_tier() == -1, "no --perf on the command line means the automatic tier")

	again.queue_free()
	await process_frame
	Lighting.tier_locked = false # leave the statics as the rest of the suite expects them
	Lighting.tier = Lighting.Quality.HIGH
	T.finish(self)
