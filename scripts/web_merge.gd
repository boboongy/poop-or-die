extends RefCounted
## Web build only (Compatibility renderer; npc_jijio.gd calls it): a Jijio is 9 skinned meshes with 17 surfaces, and WebGL pays a lot
## for every draw call (Chrome, 2026-09-28: ~1,600 draw calls = ~200 ms of render CPU per frame, 3-4 FPS). All of her materials are
## plain colours on one shared Skin, so her meshes are merged into TWO single-surface meshes whose vertex colours are the old albedo
## colours: "WebMerged_HairShirt" (named so cutters.gd, which recolours meshes whose name has Hair or Shirt, still finds it) and
## "WebMerged" (everything else). Face shape keys are merged too (a mesh without a key keeps its shape). Each merged mesh is built
## once per source model and shared by every Jijio.

const CLOTHES := ["Hair", "Shirt"]

static var _cache := {} ## first source mesh -> merged ArrayMesh
static var force := false ## tests: merge even under the headless renderer


static func wanted() -> bool:
	return force or RenderingServer.get_current_rendering_method() == "gl_compatibility"


## Returns the merged MeshInstance3Ds (none when the model is not made of several skinned meshes).
static func merge(model: Node) -> Array[MeshInstance3D]:
	var clothes: Array[MeshInstance3D] = []
	var rest: Array[MeshInstance3D] = []
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh is ArrayMesh and mi.skin != null:
			(clothes if CLOTHES.any(func(k): return mi.name.contains(k)) else rest).append(mi)
	var out: Array[MeshInstance3D] = []
	for group in [[rest, "WebMerged"], [clothes, "WebMerged_HairShirt"]]:
		var mi := _merge(group[0], group[1])
		if mi != null:
			out.append(mi)
	return out


static func _merge(parts: Array[MeshInstance3D], merged_name: String) -> MeshInstance3D:
	if parts.size() < 2:
		return null
	var first := parts[0]
	parts = parts.filter(func(p: MeshInstance3D) -> bool:
		return p.get_parent() == first.get_parent() and p.skin == first.skin and p.skeleton == first.skeleton \
			and p.transform.is_equal_approx(first.transform))
	var key: Mesh = first.mesh
	if not _cache.has(key):
		_cache[key] = _build(parts)
	var merged: ArrayMesh = _cache[key]
	var out := MeshInstance3D.new()
	out.name = merged_name
	out.mesh = merged
	out.skin = first.skin
	out.transform = first.transform
	out.cast_shadow = first.cast_shadow
	first.get_parent().add_child(out)
	out.skeleton = out.get_path_to(first.get_node(first.skeleton))
	for b in merged.get_blend_shape_count(): # keep the current face (the default expression)
		var n := String(merged.get_blend_shape_name(b))
		for p in parts:
			var i := p.find_blend_shape_by_name(n)
			if i >= 0:
				out.set_blend_shape_value(b, p.get_blend_shape_value(i))
				break
	for p in parts:
		p.get_parent().remove_child(p)
		p.queue_free()
	return out


static func _build(parts: Array[MeshInstance3D]) -> ArrayMesh:
	var eight := false
	var names: Array[StringName] = []
	for p in parts:
		var am := p.mesh as ArrayMesh
		for s in am.get_surface_count():
			eight = eight or (am.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0
		for b in am.get_blend_shape_count():
			if not names.has(am.get_blend_shape_name(b)):
				names.append(am.get_blend_shape_name(b))
	var per := 8 if eight else 4
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	var shape_verts: Array[PackedVector3Array] = []
	var shape_normals: Array[PackedVector3Array] = []
	for n in names:
		shape_verts.append(PackedVector3Array())
		shape_normals.append(PackedVector3Array())
	for p in parts:
		var am := p.mesh as ArrayMesh
		for s in am.get_surface_count():
			var arr := am.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var base := verts.size()
			var src_per := 8 if (am.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0 else 4
			var bn: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var wt: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var mat := p.get_active_material(s) as BaseMaterial3D
			var col := mat.albedo_color if mat != null else Color.WHITE
			verts.append_array(v)
			normals.append_array(nrm)
			for i in v.size():
				colours.append(col)
				for j in per:
					bones.append(bn[i * src_per + j] if j < src_per else 0)
					weights.append(wt[i * src_per + j] if j < src_per else 0.0)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
			for i in idx:
				indices.append(base + i)
			var shapes := am.surface_get_blend_shape_arrays(s)
			for k in names.size():
				var b := _find_shape(am, names[k])
				if b >= 0:
					shape_verts[k].append_array(shapes[b][Mesh.ARRAY_VERTEX])
					shape_normals[k].append_array(shapes[b][Mesh.ARRAY_NORMAL])
				else: # this part has no such key: it keeps its own shape
					shape_verts[k].append_array(v)
					shape_normals[k].append_array(nrm)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	var shape_arrays := []
	for k in names.size():
		var sa := []
		sa.resize(Mesh.ARRAY_MAX)
		sa[Mesh.ARRAY_VERTEX] = shape_verts[k]
		sa[Mesh.ARRAY_NORMAL] = shape_normals[k]
		shape_arrays.append(sa)
	var mesh := ArrayMesh.new()
	mesh.blend_shape_mode = (parts[0].mesh as ArrayMesh).blend_shape_mode
	for n in names:
		mesh.add_blend_shape(n)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, shape_arrays, {},
		Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if eight else 0)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.55
	mesh.surface_set_material(0, mat)
	return mesh


static func _find_shape(am: ArrayMesh, n: StringName) -> int:
	for b in am.get_blend_shape_count():
		if am.get_blend_shape_name(b) == n:
			return b
	return -1
