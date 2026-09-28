extends Node3D
## Level 2 "The flood" (SPEC Round 2 Stage 3, owner "yes" 2026-09-27): the water that fills the whole toilet.
## One flat sheet at `depth` metres over the floor (the floor is flat at y 0). Each running SOURCE (the clogged toilet, a tap left on)
## adds RATE_PER_SOURCE metres a second, so all five fill it to MAX_DEPTH in about 60 s; it holds there. Turning a source off slows
## the rise by a fifth. `start_drain()` works only when no source runs; then the water goes down to nothing in DRAIN_SECONDS.
## Before the floor is covered the water only shows round the sources, spreading at SPREAD_SPEED (the trickle out of the stall).
## Look: flood_water.gdshader. While the camera is under the surface the screen goes murky (fog + a tinted overlay).

signal drained ## the water is all gone
signal sources_changed

const MAX_DEPTH := 1.6
const RATE_PER_SOURCE := MAX_DEPTH / 300.0 ## m/s: five sources = 1.6 m in 60 s
const DRAIN_SECONDS := 12.0
const SPREAD_SPEED := 0.8 ## m/s: how fast the first water spreads over the dry floor from a source
const COVER_DEPTH := 0.06 ## m: from here the whole floor is under water (the spreads have met by then)
const SWIM_DEPTH := 0.75 ## deeper than this, everyone swims (player.gd, npc floating)
## The whole inside of the building: the waiting room (x -5.3..-0.15) and the toilet (x 0..12.65, z -6.1..0.95). The sheet is one
## rectangle; the parts outside the shell are behind walls.
const AREA := Rect2(-5.3, -6.1, 17.95, 8.1)
const UNDER_FOG := Color(0.2, 0.26, 0.17)
const SHADER := preload("res://scripts/flood_water.gdshader")
const Sfx := preload("res://scripts/sfx.gd")

var depth := 0.0
var draining := false
var level: Node3D
var _sources := {} ## id -> world position (floor level) of a RUNNING source
var _spreads: Array[Vector4] = [] ## where water started, and how far it has spread
var _mat: ShaderMaterial
var _sheet: MeshInstance3D
var _overlay: ColorRect
var _under := false
var _drain_pos := Vector3.ZERO
var _saved_fog := {}


func setup(level_node: Node3D) -> void:
	level = level_node
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("normal_a", _normal_tex(0.018, 1))
	_mat.set_shader_parameter("normal_b", _normal_tex(0.045, 2))
	var mesh := PlaneMesh.new()
	mesh.size = AREA.size
	mesh.subdivide_width = 179
	mesh.subdivide_depth = 80
	mesh.material = _mat
	_sheet = MeshInstance3D.new()
	_sheet.name = "WaterSheet"
	_sheet.mesh = mesh
	_sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sheet.visible = false
	add_child(_sheet)
	_sheet.position = Vector3(AREA.get_center().x, 0.0, AREA.get_center().y)
	var layer := CanvasLayer.new()
	layer.layer = 0 # under the HUD
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.color = Color(0.2, 0.27, 0.16, 0.45)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	layer.add_child(_overlay)


static func _normal_tex(frequency: float, seed_value: int) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.seed = seed_value
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.as_normal_map = true
	tex.bump_strength = 6.0
	tex.noise = noise
	return tex


## A source starts running (or keeps running): `id` names it ("toilet", "sink3"), `pos` is where it spills onto the floor.
func add_source(id: String, pos: Vector3) -> void:
	if _sources.has(id):
		return
	_sources[id] = Vector3(pos.x, 0.0, pos.z)
	if depth < COVER_DEPTH and _spreads.size() < 8:
		_spreads.append(Vector4(pos.x, 0.0, pos.z, 0.3))
	sources_changed.emit()


func remove_source(id: String) -> void:
	if _sources.erase(id):
		sources_changed.emit()


func is_running(id: String) -> bool:
	return _sources.has(id)


func running_count() -> int:
	return _sources.size()


## The plug: only when nothing is coming in any more. Returns true when the water starts to go down.
func start_drain(at: Vector3) -> bool:
	if running_count() > 0 or depth <= 0.0:
		return false
	_drain_pos = at
	draining = true
	return true


func is_full() -> bool:
	return depth >= MAX_DEPTH - 0.001


## Height of the water surface (world y) without the little waves.
func surface_y() -> float:
	return depth


## How deep the water is at `p` (0 where it has not spread yet).
func depth_at(p: Vector3) -> float:
	if depth <= 0.0 or not AREA.has_point(Vector2(p.x, p.z)):
		return 0.0
	if depth < COVER_DEPTH:
		for s in _spreads:
			if Vector2(p.x - s.x, p.z - s.z).length() < s.w:
				return depth
		return 0.0
	return depth


func _physics_process(delta: float) -> void:
	if draining:
		depth = maxf(depth - MAX_DEPTH / DRAIN_SECONDS * delta, 0.0)
		if depth <= 0.0:
			draining = false
			drained.emit()
	else:
		depth = minf(depth + RATE_PER_SOURCE * running_count() * delta, MAX_DEPTH)
	for i in _spreads.size():
		_spreads[i].w += SPREAD_SPEED * delta


func _process(_delta: float) -> void:
	_sheet.visible = depth > 0.0
	if not _sheet.visible:
		_set_under(false)
		return
	_sheet.position.y = maxf(depth, 0.008)
	_mat.set_shader_parameter("wave_amp", clampf(depth / 0.4, 0.05, 1.0))
	_mat.set_shader_parameter("cover_all", 1.0 if depth >= COVER_DEPTH else 0.0)
	var spreads: Array[Vector4] = []
	spreads.assign(_spreads)
	while spreads.size() < 8:
		spreads.append(Vector4.ZERO)
	_mat.set_shader_parameter("spread", spreads)
	_mat.set_shader_parameter("spread_count", _spreads.size())
	var boils: Array[Vector4] = []
	for id: String in _sources:
		var s: Vector3 = _sources[id]
		boils.append(Vector4(s.x, 0.0, s.z, 1.0))
	var n := boils.size()
	while boils.size() < 8:
		boils.append(Vector4.ZERO)
	_mat.set_shader_parameter("boil", boils)
	_mat.set_shader_parameter("boil_count", n)
	_mat.set_shader_parameter("drain_pos", _drain_pos)
	_mat.set_shader_parameter("swirl", 1.0 if draining else 0.0)
	var cam := get_viewport().get_camera_3d()
	_set_under(cam != null and cam.global_position.y < depth - 0.02 and AREA.has_point(Vector2(cam.global_position.x, cam.global_position.z)))
	_update_rise_sound()


## The room filling: a low slosh everywhere (2D), louder as the water rises, gone when nothing comes in any more.
const RISE_DB_LOW := -26.0
const RISE_DB_HIGH := -13.0
var _rise: AudioStreamPlayer


func _update_rise_sound() -> void:
	var rising := running_count() > 0 and depth > 0.05 and not is_full()
	if rising and _rise == null:
		_rise = Sfx.loop_ui(self, "rise")
	if _rise != null:
		if rising:
			_rise.volume_db = lerpf(RISE_DB_LOW, RISE_DB_HIGH, clampf(depth / MAX_DEPTH, 0.0, 1.0))
		else:
			Sfx.fade_out(_rise, 1.5)
			_rise = null


func is_camera_under() -> bool:
	return _under


## Under water everything sounds muffled: a low-pass at the FRONT of the Master bus (the limiter stays last, level_toilet.ensure_limiter).
static var _muffler: AudioEffectLowPassFilter


## It is added ONCE (disabled) and only switched on and off: adding or removing a bus effect mid-game rebuilds every effect on the bus
## (the windowed recorder of probe_flood_sound lost its recording at the first dive).
static func _muffler_index() -> int:
	if _muffler == null:
		_muffler = AudioEffectLowPassFilter.new()
		_muffler.cutoff_hz = 500.0
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) == _muffler:
			return i
	AudioServer.add_bus_effect(0, _muffler, 0)
	AudioServer.set_bus_effect_enabled(0, 0, false)
	return 0


func _muffle(on: bool) -> void:
	AudioServer.set_bus_effect_enabled(0, _muffler_index(), on)


func _ready() -> void:
	_muffler_index() # in place (off) before anything records or plays


func _exit_tree() -> void:
	if _under:
		_muffle(false) # a reload while Bob is under must not leave the whole game muffled


## Under the surface: thick grey-green fog and a tint (about 2 m of sight), put back when the camera comes up.
func _set_under(on: bool) -> void:
	if on == _under:
		return
	_under = on
	_overlay.visible = on
	_muffle(on)
	var we: WorldEnvironment = level.get_node_or_null("WorldEnvironment") if level else null
	if we == null or we.environment == null:
		return
	var env := we.environment
	if on:
		_saved_fog = {"on": env.fog_enabled, "color": env.fog_light_color, "density": env.fog_density, "sky": env.fog_sky_affect}
		env.fog_enabled = true
		env.fog_light_color = UNDER_FOG
		env.fog_density = 0.9
		env.fog_sky_affect = 1.0
	elif not _saved_fog.is_empty():
		env.fog_enabled = _saved_fog["on"]
		env.fog_light_color = _saved_fog["color"]
		env.fog_density = _saved_fog["density"]
		env.fog_sky_affect = _saved_fog["sky"]
