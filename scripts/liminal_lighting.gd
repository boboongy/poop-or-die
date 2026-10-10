extends Node
## Builds the liminal green-fluorescent look at runtime (lights are not in the glb).
## One shadow-casting spot light per ceiling panel, glowing panel material, glossy tile,
## bounced light (SDFGI), reflections, light haze, and a faint hum.
## Tune the exports below in the inspector, then press Play.

enum Quality { HIGH, MEDIUM, LOW }

@export var quality := Quality.HIGH

@export_group("Light")
@export var light_color := Color(0.6, 1.0, 0.65)
@export var light_energy := 2.4
@export var light_range := 7.0
@export var light_angle := 80.0
@export var panel_emission := 4.0

@export_group("Atmosphere")
@export var ambient_color := Color(0.15, 0.4, 0.2)
@export var ambient_energy := 0.2
## The web renderer's look: an ambient boost for the missing SDFGI bounce, then exposure/contrast/saturation matched to the Forward+
## editor look (owner 2026-09-28: 5x ambient was "overexposed"; tests/probe_compat_fps.gd shots side by side, Level 1 start).
const COMPAT_AMBIENT := 6.0 ## ambient 1.2: the characters have no bounced light here (owner 2026-09-28: 2.5 left them "so shadowed")
const COMPAT_LIGHT_ENERGY := 1.3 ## the lamps dimmed instead, so the walls do not wash out
const COMPAT_EXPOSURE := 0.85
const COMPAT_CONTRAST := 1.1
const COMPAT_SATURATION := 1.0
@export var fog_density := 0.02
@export var fog_color := Color(0.25, 0.85, 0.35)

@export_group("Surfaces")
@export var floor_roughness := 0.45
@export var wall_roughness := 0.6

@export_group("Hum")
@export var hum_db := -30.0

const AnimThrottle := preload("res://scripts/anim_throttle.gd")
const COMPAT_SCALE := 0.75
static var force_compat := false ## tests: act as the web build even under the headless renderer

## The automatic DESKTOP tier (owner's option A, 2026-10-10; numbers in PERF_PLAN.md "MEASURED"). The full look runs at
## 17 FPS at 1920x1080 on an integrated Radeon, which blocks the YouTube capture, so the game samples its OWN frame rate
## once per launch and drops to MEDIUM if the machine cannot afford the look.
## Measured at 1080p: HIGH 17.4 FPS -> MEDIUM 40.6 FPS, with the haze, the glow and all 10 ceiling-grid shadows kept.
## Only SDFGI's bounced light is traded away (ambient takes over, exactly as the web build does).
## Why one sample and never again: a tier that re-decides could switch quality in the middle of a recording (the owner's
## stated risk). The verdict is stored in a STATIC var, so it also survives a retry or the jump to the next level.
const PERF_BAR_FPS := 35.0 ## the full stack above this = the machine can afford HIGH (the bar for the video is 30)
const PERF_WARMUP_FRAMES := 90 ## shader compilation makes the first second far slower than the game ever is again
const PERF_SAMPLE_SECONDS := 3.0
const PERF_FOG_LENGTH := 20.0 ## m: MEDIUM keeps the green haze at half its length
## x ambient_energy (0.2) = 0.5. NOT the web build's COMPAT_AMBIENT (6.0 -> 1.2): the web renderer has no lamps to speak of,
## while this tier keeps all 10 shadow-casting spots, so 1.2 on top of them washed the room flat (2x2 contact sheet at 1080p,
## 2026-10-10: 1.2 and 0.8 both lost the dark far corridor; 0.5 matches HIGH's mood and still lifts the characters).
const PERF_AMBIENT := 2.5
const LOW_SCALE := 0.8 ## only reachable with --perf=low: 3D drawn at 0.8, the HUD stays sharp (stretch mode canvas_items)
static var tier_locked := false ## tests read and reset these two
static var tier := Quality.HIGH
var _perf_warmup := 0
var _perf_fps: Array[float] = []
var _perf_elapsed := 0.0
var _measuring := false

var _spots: Array[SpotLight3D] = []
var _shadow_wait := 0.0
var _throttle: Node = null

@onready var toilet: Node3D = $"../NavRegion/Toilet"
@onready var world_env: WorldEnvironment = $"../WorldEnvironment"


func _ready() -> void:
	_tune_materials()
	_build_lights()
	_build_reflection_probe()
	_build_hum()
	world_env.environment = _build_environment()
	# Anisotropic 16x is what fixes the tile grids' TEXTURE shimmer at a distance, and it is cheap, so every tier keeps it.
	# MSAA (geometry edges) is the expensive half and is set per tier in apply_quality; MEDIUM uses FXAA instead.
	get_viewport().anisotropic_filtering_level = Viewport.ANISOTROPY_16X
	var forced := _forced_tier()
	if is_compat(): # the web build has its own cut-down path and never measures
		apply_quality(quality)
	elif forced >= 0:
		tier = forced as Quality
		tier_locked = true
		print("PERF TIER: --perf -> ", Quality.keys()[tier])
		apply_quality(tier)
	elif tier_locked: # decided earlier this launch (a retry or the next level reloads this scene)
		apply_quality(tier)
	else:
		apply_quality(Quality.HIGH) # measure the full look, then decide in _process
		_measuring = true


func apply_quality(q: Quality) -> void:
	quality = q
	var env := world_env.environment
	var high := q == Quality.HIGH
	var medium := q != Quality.LOW
	# Measured 2026-10-10 (PERF_PLAN.md): one effect at a time changed NOTHING at 1080p on an APU (bandwidth saturation lets
	# the remaining effects fill the gap), so MEDIUM drops the whole per-pixel stack at once and keeps what carries the look:
	# the haze (shorter), the glow and every ceiling-grid shadow. 40.6 FPS against HIGH's 17.4.
	env.sdfgi_enabled = high
	env.ssr_enabled = high
	env.ssao_enabled = high
	env.volumetric_fog_enabled = medium
	env.volumetric_fog_length = 40.0 if high else PERF_FOG_LENGTH
	for spot in _spots:
		spot.shadow_enabled = medium
	# Stage 8 web build: the Compatibility renderer has no SDFGI/SSR/volumetric fog, and without the bounced light the characters were
	# near-black silhouettes (tests/shot_levels_compat.gd, 2026-09-28). There, the missing bounce is replaced by more ambient light.
	if is_compat():
		env.sdfgi_enabled = false
		env.ssr_enabled = false
		env.volumetric_fog_enabled = false
		env.ambient_light_energy = ambient_energy * COMPAT_AMBIENT
		env.tonemap_exposure = COMPAT_EXPOSURE
		for spot in _spots:
			spot.light_energy = COMPAT_LIGHT_ENERGY
		env.adjustment_contrast = COMPAT_CONTRAST
		env.adjustment_saturation = COMPAT_SATURATION
		# Speed (owner 2026-09-28: 7 FPS on github.io; tests/probe_compat_fps.gd, Level 3, 3 runs each: 8.5 -> about 31 FPS):
		# only the light nearest Bob casts shadows, no MSAA (its depth copy also failed in WebGL, which hid the flood water),
		# 3D drawn at 0.75 scale, far Jijios animated every 3rd frame.
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		get_viewport().scaling_3d_scale = COMPAT_SCALE
		_update_shadow_light()
		if _throttle == null:
			_throttle = AnimThrottle.new()
			add_child(_throttle)
			if OS.has_feature("web"):
				add_child(preload("res://scripts/web_probe.gd").new())
	else:
		# Desktop. Below HIGH there is no SDFGI bounce, so ambient takes over (PERF_AMBIENT, judged on a contact sheet),
		# and FXAA replaces MSAA.
		env.ambient_light_energy = ambient_energy * (1.0 if high else PERF_AMBIENT)
		env.tonemap_exposure = 1.0
		env.adjustment_contrast = 1.1
		env.adjustment_saturation = 0.9
		get_viewport().msaa_3d = Viewport.MSAA_4X if high else Viewport.MSAA_DISABLED
		get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if high else Viewport.SCREEN_SPACE_AA_FXAA
		get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		get_viewport().scaling_3d_scale = LOW_SCALE if q == Quality.LOW else 1.0
		for spot in _spots:
			spot.light_energy = light_energy


static func is_compat() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility" or force_compat


## Web build: only the spot light nearest Bob (the camera when there is no Bob) casts shadows.
func _update_shadow_light() -> void:
	var from: Node3D = get_tree().get_first_node_in_group("player")
	if from == null:
		from = get_viewport().get_camera_3d()
	if from == null or _spots.is_empty():
		return
	var best: SpotLight3D = _spots[0]
	for spot in _spots:
		if spot.global_position.distance_squared_to(from.global_position) < best.global_position.distance_squared_to(from.global_position):
			best = spot
	for spot in _spots:
		spot.shadow_enabled = spot == best and quality != Quality.LOW


## `--perf=high|med|low` on the command line (the owner's recording override): -1 when it was not given.
static func _forced_tier() -> int:
	var args: Array = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for a in args:
		if not String(a).begins_with("--perf="):
			continue
		match String(a).trim_prefix("--perf=").to_lower():
			"high": return Quality.HIGH
			"med", "medium": return Quality.MEDIUM
			"low": return Quality.LOW
	return -1


## Option A: sample the real frame rate once, then lock the tier for the whole launch.
func _measure_tier(delta: float) -> void:
	if _perf_warmup < PERF_WARMUP_FRAMES:
		_perf_warmup += 1
		return
	_perf_elapsed += delta
	_perf_fps.append(1.0 / maxf(delta, 0.0001))
	if _perf_elapsed < PERF_SAMPLE_SECONDS:
		return
	_measuring = false
	_perf_fps.sort()
	var median: float = _perf_fps[_perf_fps.size() / 2] # the median, so one stutter cannot demote a fast machine
	tier = Quality.HIGH if median >= PERF_BAR_FPS else Quality.MEDIUM
	tier_locked = true
	print("PERF TIER: %.0f FPS median over %.1f s (%d frames) -> %s" % [
		median, _perf_elapsed, _perf_fps.size(), Quality.keys()[tier]])
	if tier != Quality.HIGH:
		apply_quality(tier)


func _process(delta: float) -> void:
	if _measuring:
		_measure_tier(delta)
	if not is_compat():
		return
	_shadow_wait -= delta
	if _shadow_wait <= 0.0:
		_shadow_wait = 0.25
		_update_shadow_light()


func _tune_materials() -> void:
	var seen := {}
	for m in toilet.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if mat == null or seen.has(mat):
				continue
			seen[mat] = true
			match mat.resource_name:
				"M_FluoroLens":
					mat.emission_energy_multiplier = panel_emission
				"M_TileFloor":
					mat.roughness = floor_roughness
				"M_TileWall":
					mat.roughness = wall_roughness


func _build_lights() -> void:
	for m in toilet.find_children("SM_LightPanel*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var box := mi.global_transform * mi.get_aabb()
		var c := box.get_center()
		_add_spot(Vector3(c.x, box.position.y - 0.05, c.z))
	# The lobby has no light panel in the glb, so give it a light of its own.
	_add_spot(Vector3(-2.7, 2.7, 0.0))


func _add_spot(pos: Vector3) -> void:
	var spot := SpotLight3D.new()
	spot.position = pos
	spot.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	spot.light_color = light_color
	spot.light_energy = light_energy
	spot.spot_range = light_range
	spot.spot_angle = light_angle
	spot.spot_attenuation = 0.8
	spot.shadow_enabled = true
	add_child(spot)
	_spots.append(spot)


func _build_reflection_probe() -> void:
	var probe := ReflectionProbe.new()
	probe.position = Vector3(3.5, 1.4, -2.0)
	probe.size = Vector3(20.0, 2.8, 14.0)
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(probe)


func _build_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy = 0.7
	env.ssr_max_steps = 96
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.5
	env.volumetric_fog_density = fog_density
	env.volumetric_fog_albedo = fog_color
	env.volumetric_fog_emission = Color(0.0, 0.05, 0.01)
	env.volumetric_fog_length = 40.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 0.9
	return env


## A quiet fluorescent-ballast hum: 120 Hz plus harmonics, one second so the loop is seamless.
func _build_hum() -> void:
	var rate := 22050
	var data := PackedByteArray()
	data.resize(rate * 2)
	for i in rate:
		var t := float(i) / rate
		var s := 0.5 * sin(TAU * 120.0 * t) + 0.25 * sin(TAU * 240.0 * t) + 0.12 * sin(TAU * 360.0 * t)
		data.encode_s16(i * 2, int(s * 12000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = rate
	for x in [-2.7, 3.5, 9.5]:
		var player := AudioStreamPlayer3D.new()
		player.stream = stream
		player.volume_db = hum_db
		player.max_distance = 10.0
		player.position = Vector3(x, 2.5, 0.0)
		add_child(player)
		player.play()
