extends SceneTree
## Probe for Stage 6d: the shorts' seat in UV space. Vertices of Bob_Shorts within 12 cm of the seat centre (rest pose, back = -Z):
## their UVs, and how well UV distance follows 3D distance (a seam down the middle would show as big UV jumps between near vertices).
const SEAT := Vector3(0.0, 0.40, -0.10)


func _init() -> void:
	var p: Node = load("res://scenes/player.tscn").instantiate()
	root.add_child(p)
	await process_frame
	var mi: MeshInstance3D = p.find_child("Bob_Shorts", true, false)
	var arr := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var near: Array[int] = []
	var back_z := 0.0
	for i in verts.size():
		back_z = minf(back_z, verts[i].z)
	for i in verts.size():
		if verts[i].distance_to(SEAT) < 0.12 and verts[i].z < -0.03:
			near.append(i)
	var ulo := Vector2.INF
	var uhi := -Vector2.INF
	for i in near:
		ulo = ulo.min(uvs[i])
		uhi = uhi.max(uvs[i])
	print("back z %.3f; %d verts near the seat; uv %s..%s" % [back_z, near.size(), str(ulo), str(uhi)])
	var ratios: Array[float] = []
	var jumps := 0
	for a in near:
		for b in near:
			if a < b and verts[a].distance_to(verts[b]) < 0.03 and verts[a].distance_to(verts[b]) > 0.002:
				var r := uvs[a].distance_to(uvs[b]) / verts[a].distance_to(verts[b])
				ratios.append(r)
				if r > 20.0:
					jumps += 1
	ratios.sort()
	print("uv/3D ratio: min %.2f median %.2f max %.2f; jumps(>20) %d of %d pairs" % [ratios[0], ratios[ratios.size() / 2], ratios[-1], jumps, ratios.size()])
	# the seat centre's uv: the nearest back vertex
	var best := -1
	for i in near:
		if best < 0 or Vector2(verts[i].x, verts[i].y - SEAT.y).length() < Vector2(verts[best].x, verts[best].y - SEAT.y).length():
			best = i
	print("seat vertex %s uv %s" % [str(verts[best]), str(uvs[best])])
	for i in near:
		if absf(verts[i].x) < 0.01:
			print("  centre-line vertex %s uv %s" % [str(verts[i].snappedf(0.001)), str(uvs[i].snappedf(0.001))])
	quit()
