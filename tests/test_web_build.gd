extends SceneTree
## The web build's speed settings (owner 2026-09-28: github.io at 7 FPS, overexposed, no flood water), run headless by forcing the
## Compatibility path (`liminal_lighting.gd force_compat`): every Jijio merged into 2 single-surface meshes with all her vertices,
## face keys still driven, cutters.gd still recolours the hair+shirt mesh, only the spot light nearest Bob casts shadows (Bob stood
## under EVERY spot in turn), MSAA off and 0.75 scale, far Jijios animated by the throttle (manual mode, never more than 3 frames behind).
const T := preload("res://tests/t.gd")
const Progress := preload("res://scripts/progress.gd")
const Lighting := preload("res://scripts/liminal_lighting.gd")
const Cutters := preload("res://scripts/cutters.gd")
const WebMerge := preload("res://scripts/web_merge.gd")

## Vertex counts of jijio.glb (probe_compat_fps.gd chars=info, 2026-09-28): Body 4485 + 2 eyes 424 + Pants 880 + 2 sandals 510 + Tongue 144;
## Hair 803 + Shirt 1594.
const REST_VERTS := 7377
const CLOTHES_VERTS := 2397


func _init() -> void:
	seed(1)
	Lighting.force_compat = true
	WebMerge.force = true
	Progress.level = 1
	var lvl := T.level(self, true)
	await T.wait(self, 0.8)
	lvl._time_left = 100000.0
	var p: CharacterBody3D = lvl.player

	# 1. every Jijio is two merged meshes
	var jijios := get_nodes_in_group("jijio")
	var bad := 0
	for j in jijios:
		var meshes := (j as Node).find_children("*", "MeshInstance3D", true, false).filter(func(m): return (m as MeshInstance3D).skin != null)
		var names := meshes.map(func(m): return String(m.name))
		names.sort()
		var ok: bool = names == ["WebMerged", "WebMerged_HairShirt"]
		if ok:
			for m in meshes:
				var mesh: Mesh = (m as MeshInstance3D).mesh
				var want := CLOTHES_VERTS if m.name == "WebMerged_HairShirt" else REST_VERTS
				ok = ok and mesh.get_surface_count() == 1 and mesh.surface_get_array_len(0) == want
		if not ok:
			bad += 1
			if bad <= 3:
				print("  not merged right: %s %s" % [j.name, names])
	T.check(jijios.size() >= 20 and bad == 0, "all %d Jijios are 2 merged meshes (1 surface each, %d + %d vertices); wrong: %d" % [
		jijios.size(), REST_VERTS, CLOTHES_VERTS, bad])

	# 2. face keys reach the merged mesh
	var j0: Node = jijios[0]
	var merged: MeshInstance3D = j0.find_child("WebMerged", true, false)
	var key_count: int = merged.mesh.get_blend_shape_count()
	T.check(key_count > 0, "the merged mesh keeps the face shape keys (%d)" % key_count)
	if key_count > 0:
		var key := String(merged.mesh.get_blend_shape_name(0))
		j0.set_expression(key, 0.7)
		T.check(is_equal_approx(merged.get_blend_shape_value(0), 0.7), "set_expression('%s', 0.7) drives the merged mesh" % key)

	# 3. the cutters' recolour still works on the merged hair+shirt
	Cutters._tint(j0, Color.RED)
	var hs: MeshInstance3D = j0.find_child("WebMerged_HairShirt", true, false)
	var tint := hs.get_surface_override_material(0) as StandardMaterial3D
	T.check(Cutters.is_tinted(j0, Color.RED) and tint != null and not tint.vertex_color_use_as_albedo,
		"cutters.gd tints the merged hair+shirt (vertex colours off)")

	# 4. one shadow, following Bob: stand under every spot light
	var spots := lvl.find_children("*", "SpotLight3D", true, false)
	var wrong := 0
	for s in spots:
		p.global_position = Vector3((s as Node3D).global_position.x, p.global_position.y, (s as Node3D).global_position.z)
		await T.wait(self, 0.4)
		var shadowed := spots.filter(func(l): return l.shadow_enabled)
		if shadowed.size() != 1 or shadowed[0] != s:
			wrong += 1
			print("  under %s: shadowed %s" % [s.name, shadowed.map(func(l): return l.name)])
	T.check(spots.size() == 10 and wrong == 0, "only the spot above Bob casts shadows, under each of %d spots (wrong %d)" % [spots.size(), wrong])
	var vp := get_root()
	T.check(vp.msaa_3d == Viewport.MSAA_DISABLED and is_equal_approx(vp.scaling_3d_scale, 0.75), "MSAA off, 3D scale 0.75")

	# 5. the animation throttle: every Jijio's player in manual mode, far ones advanced every 3rd frame, none more than 3 frames behind
	var throttle: Node = lvl.find_children("*", "Node", true, false).filter(func(n): return n.get_script() == preload("res://scripts/anim_throttle.gd")).front()
	var cam := vp.get_camera_3d()
	var far := 0
	var manual := 0
	var max_owed := 0.0
	for f in 90:
		await process_frame
		for j in jijios:
			var ap: AnimationPlayer = j.anim()
			if ap.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
				manual += 1
			if cam.global_position.distance_to(j.global_position) >= 5.0:
				far += 1
			max_owed = maxf(max_owed, throttle._owed.get(ap, 0.0))
	T.check(manual == jijios.size() * 90, "every Jijio's AnimationPlayer is driven by the throttle (%d of %d samples)" % [manual, jijios.size() * 90])
	T.check(far > 0 and max_owed <= 3.0 / 60.0 + 0.01, "far Jijios met %d times; the most animation time owed %.3f s (at most 3 frames)" % [far, max_owed])

	Lighting.force_compat = false
	WebMerge.force = false
	lvl.queue_free()
	await process_frame
	T.finish(self)
