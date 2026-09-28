extends Node
## Stage 6d SHAT PANTS ON A LOSS (owner 2026-09-28, A-E DECIDED; numbers PROPOSAL until played): on EVERY loss (timeout kick-out, caught
## in hide-and-seek, fight K.O., the lost dance battle) a dark brown, uneven, slightly shiny patch about 15 cm across spreads over the seat
## of Bob's shorts in SPREAD_SECONDS with a wet squelch, and the camera cuts to behind Bob for CUT_SECONDS so the player sees it. It stays
## until R (the level reloads). Made in Godot only: a copy of the shorts mesh carries each vertex's rest position in its COLOR, and a
## material_overlay (shat_stain.gdshader) paints the patch; the shared M_Bob_Shorts material is never touched.

const Sfx := preload("res://scripts/sfx.gd")
const SHADER := preload("res://scripts/shat_stain.gdshader")
const SPREAD_SECONDS := 1.5 ## DECIDED (B)
const CUT_SECONDS := 1.0 ## DECIDED (D)
const CUT_DELAY := 0.3 ## s after the loss: the cut shows the patch while it spreads
const LOOK_ABOVE := 0.2 ## m: the cut looks this far above the seat (centred, the result text covered the patch)
const CUT_DISTANCE := 0.8 ## m behind the seat (1.1 made the patch too small to read, player-eye pass 2026-09-28)
const BOX_CENTER := Vector3(0.0, 0.42, 0.0) ## the shorts' box is x +-0.15, y 0.31-0.52, z +-0.10 (tests/probe_shorts.gd)
const BOX_SCALE := 0.6

var material: ShaderMaterial ## the overlay (null until the first loss)
var cut_camera: Camera3D ## the behind-Bob camera while it is current
var cuts := 0 ## how many times the camera cut to behind Bob (tests)
var _player: Node3D


func setup(player: Node3D) -> void:
	_player = player


func is_shat() -> bool:
	return material != null


func spread() -> float:
	return float(material.get_shader_parameter("spread")) if material != null else 0.0


## The loss: once per level (a second loss, e.g. a lost rematch, only replays the sound and the cut).
func shat() -> void:
	var shorts: MeshInstance3D = _player.find_child("Bob_Shorts", true, false)
	if shorts == null:
		return
	if material == null:
		_add_rest_colours(shorts)
		material = ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("box_center", BOX_CENTER)
		material.set_shader_parameter("box_scale", BOX_SCALE)
		material.set_shader_parameter("spread", 0.0)
		shorts.material_overlay = material
		var tween := create_tween()
		tween.tween_method(func(v: float) -> void: material.set_shader_parameter("spread", v), 0.0, 1.0, SPREAD_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	Sfx.play_at(self, "shat", _player.global_position + Vector3.UP * 0.45)
	_cut()


## A copy of the shorts mesh with COLOR.rgb = the rest position (normalised into the shorts' box); blend shapes and skin kept.
func _add_rest_colours(shorts: MeshInstance3D) -> void:
	var src: ArrayMesh = shorts.mesh
	var dst := ArrayMesh.new()
	dst.blend_shape_mode = src.blend_shape_mode
	for b in src.get_blend_shape_count():
		dst.add_blend_shape(src.get_blend_shape_name(b))
	var values := {}
	for b in src.get_blend_shape_count():
		var prop := "blend_shapes/" + String(src.get_blend_shape_name(b))
		values[prop] = shorts.get(prop)
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colours := PackedColorArray()
		colours.resize(verts.size())
		for i in verts.size():
			var c := (verts[i] - BOX_CENTER) / BOX_SCALE + Vector3(0.5, 0.5, 0.5)
			colours[i] = Color(c.x, c.y, c.z, 1.0)
		arrays[Mesh.ARRAY_COLOR] = colours
		var flags := src.surface_get_format(s) & ~Mesh.ARRAY_FORMAT_VERTEX & ~Mesh.ARRAY_FORMAT_NORMAL & ~Mesh.ARRAY_FORMAT_TANGENT \
			& ~Mesh.ARRAY_FORMAT_COLOR & ~Mesh.ARRAY_FORMAT_TEX_UV & ~Mesh.ARRAY_FORMAT_TEX_UV2 & ~Mesh.ARRAY_FORMAT_BONES & ~Mesh.ARRAY_FORMAT_WEIGHTS \
			& ~Mesh.ARRAY_FORMAT_INDEX
		flags &= Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS | Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE
		dst.add_surface_from_arrays(src.surface_get_primitive_type(s), arrays, src.surface_get_blend_shape_arrays(s), {}, flags)
		dst.surface_set_material(s, src.surface_get_material(s))
	shorts.mesh = dst
	for prop: String in values:
		shorts.set(prop, values[prop])


## (D) a short cut to behind Bob, looking at the seat of his shorts; then back to whatever camera was showing.
func _cut() -> void:
	await get_tree().create_timer(CUT_DELAY, false).timeout
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		return
	var before := _player.get_viewport().get_camera_3d()
	var model: Node3D = _player.get_node_or_null("Model")
	var basis: Basis = (model if model != null else _player).global_transform.basis
	var back := -basis.z.normalized() # the model faces +Z: behind him is -Z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else Vector3.BACK
	var seat := _player.global_position + Vector3.UP * 0.42
	cut_camera = Camera3D.new()
	cut_camera.fov = 50.0
	cut_camera.near = 0.02
	_player.get_parent().add_child(cut_camera)
	var from := seat + back * CUT_DISTANCE + Vector3.UP * 0.2
	# a wall right behind him: move the camera in until the view to the seat is clear
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(seat, from, 1))
	if not hit.is_empty():
		from = seat + (hit["position"] - seat) * 0.85
	cut_camera.global_position = from
	cut_camera.look_at(seat + Vector3.UP * LOOK_ABOVE, Vector3.UP) # the seat in the lower part of the frame, under the result text
	var fill := OmniLight3D.new() # a warm fill on the seat for the cut only: in the crowd his back is in deep shadow (player-eye pass)
	fill.light_color = Color(1.0, 0.85, 0.7)
	fill.light_energy = 1.2
	fill.omni_range = 1.6
	fill.shadow_enabled = false
	cut_camera.add_child(fill)
	cut_camera.make_current()
	cuts += 1
	await get_tree().create_timer(CUT_SECONDS, true, false, true).timeout
	if is_instance_valid(before) and before.is_inside_tree():
		before.make_current()
	if is_instance_valid(cut_camera):
		cut_camera.queue_free()
	cut_camera = null
