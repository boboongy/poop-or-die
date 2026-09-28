extends Node
## The mop in Bob's hands (Level 2). Hold Q to take it out (walking pace only) and face the water: the circle lands within REACH of
## Bob along where the crosshair looks (no camera tilt needed) and snaps onto the wettest patch nearby. Right-click = one stroke
## (0.4 s swing) that dries the flood under the circle; HOLD right-click to keep mopping.
## A stroke on dry floor still swings but dries nothing (the circle is red then, green when it is on water).
## The mop itself is a stand-in shape (FACTORY_TODO.md batch 4).

const Sfx := preload("res://scripts/sfx.gd")

const REACH := 1.5
const Flood := preload("res://scripts/flood.gd")
const STROKE_SECONDS := 0.4 ## was 0.5 (owner 2026-09-21: mopping took too long)
const SNAP_RADIUS := 0.7 ## the circle snaps onto the wettest patch this near the crosshair
const DEFAULT_AHEAD := 1.0 ## looking up: the circle goes this far in front of Bob
const HOLD_DELAY := 0.15 ## holding right-click longer than this keeps mopping
## Where the mop head is, in Bob's model space (his front is +Z). At rest he holds it upright at his side (it stays visible: a mop
## that vanishes after the pickup looked like a bug to the owner, 2026-09-21); holding Q swings it out onto the floor in front of him.
const REST_POS := Vector3(0.4, 0.0, 0.1)
const REST_ROT := Vector3(0.0, 0.0, 0.0)
const ACTIVE_POS := Vector3(0.28, 0.0, 0.75)
const ACTIVE_ROT := Vector3(-0.35, 0.0, 0.0) ## the handle leans back toward his hands

var owned := false
var strokes := 0 ## strokes made (any, in reach or not)
var target := Vector3.ZERO ## where the circle is on the floor (valid when target_valid)
var target_valid := false
var in_reach := false ## the circle is within REACH of Bob (always, since the aim is clamped; kept for the tests)
var on_water := false ## there is water under the circle: a stroke would dry something

var _level: Node3D
var _player: CharacterBody3D
var _pivot: Node3D ## turns on Bob's model: the mop head sweeps across in front of him
var _mop: Node3D
var _marker: MeshInstance3D
var _marker_mat: StandardMaterial3D
var _cross: Label
var _swinging := false
var _hold := 0.0 ## seconds right-click has been held


func setup(level: Node3D) -> void:
	_level = level
	_player = level.player
	var layer := CanvasLayer.new()
	layer.name = "MopHud"
	add_child(layer)
	_cross = Label.new()
	_cross.text = "+"
	_cross.add_theme_font_size_override("font_size", 28)
	_cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_cross.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cross.grow_vertical = Control.GROW_DIRECTION_BOTH
	_cross.visible = false
	layer.add_child(_cross)
	_marker = MeshInstance3D.new()
	_marker.name = "MopMarker"
	var disc := CylinderMesh.new()
	disc.top_radius = Flood.STROKE_RADIUS
	disc.bottom_radius = Flood.STROKE_RADIUS
	disc.height = 0.004
	disc.radial_segments = 24
	_marker.mesh = disc
	_marker_mat = StandardMaterial3D.new()
	_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker.material_override = _marker_mat
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false
	add_child(_marker)


## Bob got the mop (the node comes from the mop prop, already carried by him).
func give(mop: Node3D) -> void:
	_pivot = Node3D.new()
	_pivot.name = "MopPivot"
	_player.model().add_child(_pivot)
	_mop = mop
	_mop.reparent(_pivot, false)
	_mop.position = REST_POS
	_mop.rotation = REST_ROT
	owned = true
	_player.carrying_changed.emit("Carrying: mop   (hold Q to mop)")


## True when the mop is down at his side (not raised to mop).
func at_rest() -> bool:
	return _mop != null and _mop.position.distance_to(REST_POS) < 0.03


func is_held() -> bool:
	return owned and Input.is_action_pressed("mop_hold") and not _player.busy and not _player.frozen and _player.slip_left <= 0.0


func _process(delta: float) -> void:
	if not owned:
		return
	var held := is_held()
	_player.sprint_blocked = held
	# The mop stays in his hand until the missions are done (then he has no more use for it).
	_pivot.visible = not _level.get("_all_done")
	var k := clampf(delta * 14.0, 0.0, 1.0)
	_mop.position = _mop.position.lerp(ACTIVE_POS if held else REST_POS, k)
	_mop.rotation = _mop.rotation.lerp(ACTIVE_ROT if held else REST_ROT, k)
	_cross.visible = held
	if not held:
		_marker.visible = false
		_hold = 0.0
		return
	_aim()
	_marker.visible = target_valid
	if _marker.visible:
		_marker.global_position = target + Vector3(0.0, 0.025, 0.0)
		_marker_mat.albedo_color = Color(0.2, 1.0, 0.4, 0.35) if on_water else Color(1.0, 0.25, 0.2, 0.35)
	# Hold right-click: a stroke every STROKE_SECONDS until let go (a plain click, shorter than HOLD_DELAY, is exactly one stroke).
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_hold += delta
		if _hold >= HOLD_DELAY and not _swinging:
			stroke()
	else:
		_hold = 0.0


## Where the mop will land. Made easy on purpose (owner, 2026-09-21: "can't finish in time, make controlling the mop easier"):
##  - the crosshair ray meets the floor, but the point is CLAMPED to REACH along the look direction, so nobody has to tilt the camera
##    down to bring the water within reach (facing the water is enough); looking up puts the circle DEFAULT_AHEAD in front of Bob;
##  - then it SNAPS onto the wettest patch within SNAP_RADIUS of that point (and within REACH of Bob);
##  - `on_water` says whether there is water under the circle (the circle is green then, red when a stroke would dry nothing).
func _aim() -> void:
	target_valid = false
	in_reach = false
	on_water = false
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var bob := _player.global_position
	var centre := get_viewport().get_visible_rect().size / 2.0
	var origin := cam.project_ray_origin(centre)
	var dir := cam.project_ray_normal(centre)
	var raw: Vector3
	if dir.y < -0.01:
		raw = origin + dir * (-origin.y / dir.y)
	else: # looking level or up: the floor a step ahead of Bob, along where the camera looks
		var flat := Vector2(dir.x, dir.z)
		flat = flat.normalized() if flat.length() > 0.001 else Vector2(0.0, -1.0)
		raw = Vector3(bob.x + flat.x * DEFAULT_AHEAD, 0.0, bob.z + flat.y * DEFAULT_AHEAD)
	var to := Vector2(raw.x - bob.x, raw.z - bob.z)
	if to.length() > REACH:
		to = to.normalized() * REACH
	raw = Vector3(bob.x + to.x, 0.0, bob.z + to.y)
	target = _snap_to_water(raw, bob)
	target_valid = true
	in_reach = Vector2(target.x - bob.x, target.z - bob.z).length() <= REACH + 0.001
	on_water = _wetness_at(target) > 0.0


## The centre of the wettest patch near `raw` (most water within one stroke's radius), or `raw` when there is no water near.
func _snap_to_water(raw: Vector3, bob: Vector3) -> Vector3:
	var near: Array = []
	for f in _level.floods:
		if Vector2(f.source.x - raw.x, f.source.z - raw.z).length() < 3.0: # only puddles that can be near the circle
			near.append(f)
	var best := raw
	var best_score := 0.0
	var best_dist := INF
	for f in near:
		for c in f.wet.size():
			if f.wet[c] <= 0.0:
				continue
			var at: Vector3 = f.cell_center(c % f.GRID, c / f.GRID)
			var d := Vector2(at.x - raw.x, at.z - raw.z).length()
			if d > SNAP_RADIUS or Vector2(at.x - bob.x, at.z - bob.z).length() > REACH:
				continue
			var score := 0.0
			for g in near:
				for e in g.wet.size():
					if g.wet[e] > 0.0 and g.cell_center(e % g.GRID, e / g.GRID).distance_to(at) <= Flood.STROKE_RADIUS:
						score += g.wet[e]
			if score > best_score + 0.01 or (absf(score - best_score) <= 0.01 and d < best_dist):
				best_score = score
				best_dist = d
				best = at
	return best


func _wetness_at(at: Vector3) -> float:
	var w := 0.0
	for f in _level.floods:
		w = maxf(w, f.wetness_at(at))
	return w


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and is_held():
		stroke()


## One stroke at the crosshair. Returns the number of puddle cells it touched (0 when out of reach or nothing wet there).
func stroke() -> int:
	if _swinging or not owned:
		return 0
	_aim()
	_swinging = true
	strokes += 1
	var touched := 0
	var at := target if target_valid else _player.global_position
	if target_valid:
		_player.turn_toward(target)
	if in_reach:
		for f in _level.floods: # every puddle under the circle (two can touch the same spot)
			touched += f.mop(target)
	Sfx.play_at(self, "mop", at)
	_pivot.rotation.y = -0.5
	var swing := create_tween()
	swing.tween_property(_pivot, "rotation:y", 0.5, STROKE_SECONDS)
	await swing.finished
	_pivot.rotation.y = 0.0
	_swinging = false
	return touched
